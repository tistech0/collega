"""Vidage complet du contenu (chantier 4, spec § 8), Postgres réel."""

import asyncio
import os
import subprocess
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path

import pytest
from sqlalchemy import func, select

from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.content import CollegePage
from app.models.generation_job import GenerationJob
from app.models.item_title import ItemTitle
from app.models.user import User
from app.services.content import store
from app.services.jobs.job_events import record_job_event
from scripts.wipe_content import count_active_jobs, main, run, table_counts, wipe_db, wipe_files
from tests.factories import cards, make_card, make_college, make_draft, make_item, make_job, make_job_page, make_user
from tests.pg import TEST_PG_URL

_BACKEND_DIR = Path(__file__).resolve().parents[2]

pytestmark = pytest.mark.pg


async def _seed(db) -> tuple[User, User, College, GenerationJob]:
    user = await make_user(db, monthly_reloads=3)
    user.monthly_reloads_reset_at = datetime.now(UTC)
    other_user = await make_user(db, monthly_reloads=7)
    other_user.monthly_reloads_reset_at = datetime.now(UTC)

    college = await make_college(db, user, status="generation_complete")
    item = await make_item(db, college, 304, text="texte item 304")
    gen = await store.put_generation(db, item.text_hash, "v1", cards("Q"), "m", 1, 1)
    await make_card(db, item, generation_id=gen.id)

    job = await make_job(db, college, status="generation_complete")
    await make_job_page(db, job, 0, "texte page brouillon")
    await record_job_event(db, job.id, "generation_progress", message="item 304", page=1, total=1)
    # Item devenu texte insuffisant : génération à 0 fiche, jamais purgée par
    # purge_unreferenced_content, mais doit disparaître au vidage.
    await make_draft(db, job, 305, "sommaire seul", cards=[], insufficient_text=True)

    h = await store.put_page(db, "page en service", [], 0.9, "pdfplumber")
    db.add(CollegePage(college_id=college.id, page_number=0, page_hash=h))

    db.add(
        ClaudeUsage(
            id=uuid.uuid4(),
            kind="generation",
            model="claude-sonnet-5",
            input_tokens=10,
            output_tokens=5,
            user_id=user.id,
            college_id=college.id,
            job_id=job.id,
        )
    )
    db.add(ItemTitle(item_number=304, label="Titre officiel", source="official"))
    db.add(ItemTitle(item_number=305, label="Titre extrait", source="extracted"))
    await db.flush()
    return user, other_user, college, job


_WIPED_EMPTY = (
    "colleges",
    "items",
    "flash_cards",
    "generation_jobs",
    "generation_job_events",
    "college_pages",
    "job_pages",
    "job_items",
    "ocr_pages",
    "item_texts",
    "item_generations",
)


async def test_wipes_content_keeps_accounts_and_usage(pg_session):
    user, other_user, college, job = await _seed(pg_session)
    await pg_session.commit()

    before = await table_counts(pg_session)
    assert before["colleges"] == 1 and before["item_generations"] == 2 and before["item_titles"] == 2

    await wipe_db(pg_session)
    await pg_session.commit()
    after = await table_counts(pg_session)

    for table in _WIPED_EMPTY:
        assert after[table] == 0, table

    # item_titles : seul le titre officiel reste.
    remaining_titles = (await pg_session.execute(select(ItemTitle))).scalars().all()
    assert [(t.item_number, t.source) for t in remaining_titles] == [(304, "official")]

    # users : conservés, quota remis à zéro.
    assert after["users"] == 2
    refreshed = (await pg_session.execute(select(User).order_by(User.email))).scalars().all()
    assert all(u.monthly_reloads == 0 and u.monthly_reloads_reset_at is None for u in refreshed)
    assert {u.id for u in refreshed} == {user.id, other_user.id}

    # claude_usage : conservé, mais délié du collège et du job supprimés.
    assert after["claude_usage"] == 1
    usage = (await pg_session.execute(select(ClaudeUsage))).scalar_one()
    assert usage.user_id == user.id
    assert usage.college_id is None
    assert usage.job_id is None
    assert (usage.input_tokens, usage.output_tokens) == (10, 5)


async def test_wipe_is_a_single_transaction_scoped_to_the_caller(pg_session):
    """`wipe_db` ne commit pas elle-même : un rollback annule tout."""
    await _seed(pg_session)
    await pg_session.commit()
    before = await table_counts(pg_session)

    await wipe_db(pg_session)
    await pg_session.rollback()

    after = await table_counts(pg_session)
    assert after == before


async def test_count_active_jobs_counts_only_active_statuses(pg_session):
    _, _, college, job = await _seed(pg_session)  # job : generation_complete (pas actif)
    await make_job(pg_session, college, status="processing")
    await make_job(pg_session, college, status="failed")
    await pg_session.commit()
    assert await count_active_jobs(pg_session) == 1


async def test_refuses_when_an_import_is_active(pg_session, tmp_path, capsys):
    """Important 2 (revue) : un import en cours (`ACTIVE_JOB_STATUSES`) fait
    refuser le vidage, base et fichiers intacts."""
    user, other_user, college, job = await _seed(pg_session)
    job.status = "ocr_complete"  # génération Claude pas terminée
    await pg_session.commit()
    before = await table_counts(pg_session)
    (tmp_path / "garde.pdf").write_bytes(b"%PDF")

    code = await run(TEST_PG_URL, tmp_path)

    assert code == 1
    assert "en cours" in capsys.readouterr().err
    assert (tmp_path / "garde.pdf").exists()  # les fichiers ne sont jamais atteints
    assert await table_counts(pg_session) == before  # rien touché en base, même connexion


def test_wipe_files_removes_pdfs_and_uploads_dir(tmp_path):
    (tmp_path / "a.pdf").write_bytes(b"%PDF")
    (tmp_path / "b.pdf").write_bytes(b"%PDF")
    (tmp_path / "note.txt").write_text("garde-moi")
    uploads = tmp_path / "uploads"
    (uploads / "upload-1").mkdir(parents=True)
    (uploads / "upload-1" / "part_0").write_bytes(b"x")
    (uploads / "upload-2").mkdir(parents=True)

    removed = wipe_files(tmp_path)

    assert removed == {"pdfs": 2, "uploads": 2}
    assert list(tmp_path.glob("*.pdf")) == []
    assert not uploads.exists()
    assert (tmp_path / "note.txt").exists()


def test_wipe_files_handles_missing_uploads_dir(tmp_path):
    (tmp_path / "a.pdf").write_bytes(b"%PDF")
    assert wipe_files(tmp_path) == {"pdfs": 1, "uploads": 0}


def test_refuses_without_confirm(capsys):
    assert main([]) == 1
    assert "confirm" in capsys.readouterr().err


def test_module_entry_point_refuses_without_confirm():
    """Important 1 (revue) : couvre le vrai point d'entrée prod, `python -m
    scripts.wipe_content` (`python scripts/wipe_content.py` échoue dans le
    conteneur : `sys.path[0]` devient `/app/scripts`, `ModuleNotFoundError:
    app` — cf. docstring du script)."""
    env = {
        **os.environ,
        "DATABASE_URL": TEST_PG_URL,
        "REDIS_URL": "redis://localhost:6379/0",
        "SECRET_KEY": "test-secret-key-for-pytest-only",
        "REVENUECAT_WEBHOOK_SECRET": "test-rc-secret",
        "CLAUDE_API_KEY": "test-key",
        "ADMIN_USERNAME": "admin",
        "ADMIN_PASSWORD": "testpass",
    }
    result = subprocess.run(
        [sys.executable, "-m", "scripts.wipe_content"],
        cwd=_BACKEND_DIR,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode != 0
    assert "confirm" in result.stderr


async def test_confirm_wipes_via_main(pg_engine, pg_factory, tmp_path, monkeypatch, capsys):
    async with pg_factory() as db:
        await _seed(db)
        await db.commit()

    from app.core.config import settings

    monkeypatch.setattr(settings, "database_url", TEST_PG_URL)
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    (tmp_path / "reste.pdf").write_bytes(b"%PDF")

    assert await asyncio.to_thread(main, ["--confirm"]) == 0

    out = capsys.readouterr().out
    assert "colleges" in out and "claude_usage" in out
    assert "1 PDF" in out
    assert not (tmp_path / "reste.pdf").exists()

    async with pg_factory() as db:
        assert (await db.execute(select(func.count()).select_from(College))).scalar_one() == 0
        assert (await db.execute(select(func.count()).select_from(ClaudeUsage))).scalar_one() == 1
