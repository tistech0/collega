"""Purges du contenu partagé et des PDF (chantier 1), Postgres réel."""

import os
import time
import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import func, select

from app.core.config import settings
from app.models.college import College
from app.models.content import CollegePage, ItemGeneration, ItemText, OcrPage
from app.models.user import User
from app.services.content import store
from app.services.content.purge import active_pdf_names, purge_orphan_pdfs, purge_unreferenced_content
from tests.api_pg import login_as
from tests.factories import cards, make_card, make_college, make_draft, make_item, make_job, make_user, write_pdf

pytestmark = pytest.mark.pg


async def _college_with_content(db, *, text="texte partagé", page="page partagée", user=None):
    user = user or await make_user(db)
    college = await make_college(db, user, status="generation_complete")
    item = await make_item(db, college, 304, text=text)
    gen = await store.put_generation(db, item.text_hash, "v1", cards("Q"), "m", 1, 1)
    await make_card(db, item, generation_id=gen.id)
    h = await store.put_page(db, page, [], 0.9, "pdfplumber")
    db.add(CollegePage(college_id=college.id, page_number=0, page_hash=h))
    await db.flush()
    return user, college


async def _counts(db):
    counts = []
    for model in (OcrPage, ItemText, ItemGeneration):
        counts.append((await db.execute(select(func.count()).select_from(model))).scalar_one())
    return tuple(counts)


async def test_content_of_deleted_college_is_purged(pg_session):
    _, college = await _college_with_content(pg_session)
    await pg_session.commit()
    await pg_session.delete(await pg_session.get(College, college.id))
    await pg_session.commit()
    counts = await purge_unreferenced_content(pg_session)
    await pg_session.commit()
    assert counts == {"item_generations": 1, "item_texts": 1, "ocr_pages": 1}
    assert await _counts(pg_session) == (0, 0, 0)


async def test_content_shared_with_another_college_is_kept(pg_session):
    _, c1 = await _college_with_content(pg_session)
    await _college_with_content(pg_session)  # même PDF chez une autre utilisatrice
    await pg_session.commit()
    await pg_session.delete(await pg_session.get(College, c1.id))
    await pg_session.commit()
    await purge_unreferenced_content(pg_session)
    await pg_session.commit()
    assert await _counts(pg_session) == (1, 1, 1)


async def test_draft_of_running_import_is_kept(pg_session):
    user = await make_user(pg_session)
    college = await make_college(pg_session, user)
    job = await make_job(pg_session, college, status="ocr_complete")
    await make_draft(pg_session, job, 304, "brouillon", cards("Q"))
    await pg_session.commit()
    await purge_unreferenced_content(pg_session)
    await pg_session.commit()
    assert await _counts(pg_session) == (0, 1, 1)


async def test_account_deletion_removes_pdfs_and_private_content(pg_client, pg_factory, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    async with pg_factory() as db:
        user, college = await _college_with_content(db, text="à moi seule", page="page à moi")
        job = await make_job(db, college, status="generation_complete")
        _, other = await _college_with_content(db, text="à une autre", page="page autre")
        await db.commit()
    pdf = write_pdf(tmp_path, college, job)
    login_as(user)

    resp = await pg_client.delete("/v1/auth/account")

    assert resp.status_code == 200
    assert not pdf.exists()
    async with pg_factory() as s:
        assert await s.get(User, user.id) is None
        assert await _counts(s) == (1, 1, 1)  # le contenu de l'autre utilisatrice reste


def _touch(path, age_hours=0):
    path.write_bytes(b"%PDF")
    t = time.time() - age_hours * 3600
    os.utime(path, (t, t))


async def test_orphan_pdfs(pg_session, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    user = await make_user(pg_session)
    college = await make_college(pg_session, user, status="generation_complete")
    old = await make_job(pg_session, college, status="generation_complete")
    current = await make_job(pg_session, college, status="generation_complete")
    running = await make_job(pg_session, await make_college(pg_session, user, ref_id=3), status="processing")
    await pg_session.commit()
    keep = await active_pdf_names(pg_session)
    assert keep == {f"{college.id}_{current.id}.pdf", f"{running.college_id}_{running.id}.pdf"}

    for name in keep | {f"{college.id}_{old.id}.pdf", f"{uuid.uuid4()}_{uuid.uuid4()}.pdf"}:
        _touch(tmp_path / name, age_hours=30)
    being_written = f"{uuid.uuid4()}_{uuid.uuid4()}.pdf"  # import pas encore en base
    _touch(tmp_path / being_written)
    _touch(tmp_path / "incoming_recent.pdf")
    _touch(tmp_path / "incoming_old.pdf", age_hours=25)

    assert purge_orphan_pdfs(keep, datetime.now(UTC)) == 3
    assert {p.name for p in tmp_path.glob("*.pdf")} == keep | {"incoming_recent.pdf", being_written}


async def test_purge_waits_for_imports_writing_content(pg_factory):
    """Un import qui vient de « retrouver » une page (ON CONFLICT DO NOTHING) tient le
    verrou partagé jusqu'à son commit : la purge (verrou exclusif) attend."""
    from sqlalchemy import text as sql_text
    from sqlalchemy.exc import DBAPIError

    async with pg_factory() as importing, pg_factory() as purging:
        await store.put_page(importing, "page partagée", [], 0.9, "pdfplumber")  # transaction ouverte
        await purging.execute(sql_text("SET LOCAL lock_timeout = '200ms'"))
        with pytest.raises(DBAPIError, match="lock timeout"):
            await purge_unreferenced_content(purging)
        await purging.rollback()
        await importing.commit()
        await purge_unreferenced_content(purging)  # l'import a fini : la purge passe
        await purging.commit()
