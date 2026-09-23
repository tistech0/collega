import pytest
from sqlalchemy import func, select

from app.models.content import ItemGeneration, OcrPage
from app.services.content import store
from app.services.content.fingerprint import item_hash
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


async def test_same_page_is_stored_once(pg_session):
    h1 = await store.put_page(pg_session, "texte", [[["A"]]], 0.9, "pdfplumber")
    h2 = await store.put_page(pg_session, "texte", [[["A"]]], 0.9, "pdfplumber")
    await pg_session.commit()
    assert h1 == h2
    assert (await pg_session.execute(select(func.count()).select_from(OcrPage))).scalar_one() == 1
    pages = await store.load_pages(pg_session, [h1])
    assert pages[h1].text == "texte" and pages[h1].tables_json == '[[["A"]]]'


async def test_item_text_keyed_by_normalized_hash_keeps_raw_text(pg_session):
    h = await store.put_item_text(pg_session, "Le foie\n233\nsain")
    await pg_session.commit()
    assert h == item_hash("Le foie\n999\nsain")
    assert await store.get_item_text(pg_session, h) == "Le foie\n233\nsain"


async def test_generation_is_unique_per_hash_and_version(pg_session):
    h = await store.put_item_text(pg_session, "texte item")
    cards = [{"card_type": "classique", "recto": "Q ?", "verso": "R"}]
    g1 = await store.put_generation(pg_session, h, "v1", cards, "m", 10, 5)
    g2 = await store.put_generation(pg_session, h, "v1", [], "m", 99, 99)
    await pg_session.commit()
    assert g1.id == g2.id and store.generation_cards(g2) == cards
    assert await store.find_generation(pg_session, h, "v2") is None
    g3 = await store.put_generation(pg_session, h, "v2", cards, "m", 1, 1)
    await pg_session.commit()
    assert g3.id != g1.id
    assert (await pg_session.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2


async def test_load_pages_empty(pg_session):
    assert await store.load_pages(pg_session, []) == {}
