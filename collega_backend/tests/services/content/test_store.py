import pytest
from sqlalchemy import func, select

from app.models.content import ItemGeneration, ItemText, OcrPage
from app.services.content import store
from app.services.content.fingerprint import item_hash

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
    h = await store.put_item_text(pg_session, ["Le foie\nsain\n233", "234\nsuite"])
    await pg_session.commit()
    assert h == item_hash(["Le foie\nsain\n999", "1000\nsuite"])
    # Affichage (régénération) : pages jointes par des retours à la ligne.
    assert await store.get_item_text(pg_session, h) == "Le foie\nsain\n233\n234\nsuite"
    # Génération : les pages se redécoupent (séparateur de page « \f » dans item_texts).
    assert await store.get_item_pages(pg_session, h) == ["Le foie\nsain\n233", "234\nsuite"]


async def test_form_feed_inside_a_page_does_not_split_it(pg_session):
    pages = ["p1 ligne\fsuite", "p2"]
    h = await store.put_item_text(pg_session, pages)
    await pg_session.commit()
    assert h == item_hash(pages)  # empreinte calculée sur les pages d'origine, inchangée
    assert await store.get_item_pages(pg_session, h) == ["p1 ligne\nsuite", "p2"]


async def test_old_item_text_without_page_separator_is_one_page(pg_session):
    pg_session.add(ItemText(hash="h" * 64, text="ancien\ntexte"))
    await pg_session.commit()
    assert await store.get_item_pages(pg_session, "h" * 64) == ["ancien\ntexte"]
    assert await store.get_item_pages(pg_session, "x" * 64) is None


async def test_insufficient_generation_is_stored_with_its_flag(pg_session):
    h = await store.put_item_text(pg_session, ["sommaire"])
    gen = await store.put_generation(pg_session, h, "v1", [], "m", 10, 5, insufficient_text=True)
    await pg_session.commit()
    assert gen.insufficient_text is True and store.generation_cards(gen) == []


async def test_generation_is_unique_per_hash_and_version(pg_session):
    h = await store.put_item_text(pg_session, ["texte item"])
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
