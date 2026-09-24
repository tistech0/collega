"""Remplissage du stockage de contenu des collèges existants (chantier 1), Postgres réel."""
import pytest
from sqlalchemy import func, select

from app.models.content import CollegePage, ItemGeneration, OcrPage
from app.models.flash_card import FlashCard
from app.models.item import Item
from app.services.content.fingerprint import item_hash
from scripts.backfill_content_store import backfill_college
from tests.factories import make_card, make_college, make_item, make_job, make_user, write_pdf
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401
from tests.workers.test_ocr_pipeline import FakeDetector, FakeProcessor

pytestmark = pytest.mark.pg

PAGES = ["ITEM 304 Foie\ntexte 304", "suite 304", "ITEM 306 Absent\ntexte 306"]


async def _seed(pg_session, tmp_path, *, with_pdf=True):
    user = await make_user(pg_session)
    college = await make_college(pg_session, user, status="generation_complete")
    job = await make_job(pg_session, college, status="generation_complete")
    for n in (304, 305):
        item = await make_item(pg_session, college, n, text=None)
        await make_card(pg_session, item)
    await pg_session.commit()
    if with_pdf:
        write_pdf(tmp_path, college, job)
    return college


async def _run(pg_session, college, tmp_path):
    return await backfill_college(
        pg_session, college, processor=FakeProcessor(PAGES), detector=FakeDetector(), pdf_dir=tmp_path
    )


async def test_fills_pages_and_matching_items_only(pg_session, tmp_path):
    college = await _seed(pg_session, tmp_path)
    report = await _run(pg_session, college, tmp_path)
    await pg_session.commit()

    assert (report["pages"], report["matched"], report["unmatched"], report["without_hash"]) == (3, [304], [306], [305])
    items = {i.item_number: i for i in (await pg_session.execute(select(Item))).scalars()}
    assert items[304].text_hash == item_hash(["ITEM 304 Foie\ntexte 304", "suite 304"])
    assert items[305].text_hash is None
    assert (await pg_session.execute(select(func.count()).select_from(CollegePage))).scalar_one() == 3
    # Rien d'autre ne bouge : pas d'item créé, fiches intactes, aucune génération.
    assert (await pg_session.execute(select(func.count()).select_from(Item))).scalar_one() == 2
    assert (await pg_session.execute(select(func.count()).select_from(FlashCard))).scalar_one() == 2
    assert (await pg_session.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 0


async def test_idempotent(pg_session, tmp_path):
    college = await _seed(pg_session, tmp_path)
    first = await _run(pg_session, college, tmp_path)
    await pg_session.commit()
    second = await _run(pg_session, college, tmp_path)
    await pg_session.commit()
    assert first == second
    assert (await pg_session.execute(select(func.count()).select_from(CollegePage))).scalar_one() == 3
    assert (await pg_session.execute(select(func.count()).select_from(OcrPage))).scalar_one() == 3


async def test_dry_run_writes_nothing(pg_session, tmp_path):
    college = await _seed(pg_session, tmp_path)
    await _run(pg_session, college, tmp_path)
    await pg_session.rollback()
    assert (await pg_session.execute(select(func.count()).select_from(OcrPage))).scalar_one() == 0
    assert all(i.text_hash is None for i in (await pg_session.execute(select(Item))).scalars())


async def test_missing_pdf_is_reported(pg_session, tmp_path):
    college = await _seed(pg_session, tmp_path, with_pdf=False)
    report = await _run(pg_session, college, tmp_path)
    assert report["error"] == "PDF en service introuvable"
