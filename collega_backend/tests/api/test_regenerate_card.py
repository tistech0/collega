"""POST /v1/flash-cards/{id}/regenerate (chantier 1) : texte source toujours disponible."""
from unittest.mock import AsyncMock

import pytest

from app.api.v1 import flash_cards as flash_cards_module
from app.deps import require_subscription
from app.models.flash_card import FlashCard
from app.schemas.college import FlashCardData
from tests.api_pg import login_as, pg_client  # noqa: F401
from tests.factories import make_card, make_college, make_item, make_user
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


async def _seed(pg_factory, *, text):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        item = await make_item(db, college, 304, text=text)
        card = await make_card(db, item, recto="Q vague ?", user_feedback="negative")
        await db.commit()
    return user, card


async def test_regenerate_uses_stored_source_text_and_drops_origin(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory, text="Le foie {texte source}\n233")
    login_as(user)
    app.dependency_overrides[require_subscription] = lambda: user
    regen = AsyncMock(return_value=FlashCardData(
        id=str(card.id), item_id=str(card.item_id), college_id=str(card.college_id), card_type="classique",
        rang="A", recto="Q précise ?", verso="R", ocr_confidence_score=0.9, low_confidence=False,
    ))
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": "trop vague"})

    assert resp.status_code == 200 and resp.json()["data"]["recto"] == "Q précise ?"
    _card, _item, source_text, note = regen.await_args.args
    assert (source_text, note) == ("Le foie {texte source}\n233", "trop vague")
    async with pg_factory() as s:
        saved = await s.get(FlashCard, card.id)
        assert (saved.recto, saved.user_feedback, saved.generation_id) == ("Q précise ?", None, None)


async def test_regenerate_without_source_text_is_409(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory, text=None)
    app.dependency_overrides[require_subscription] = lambda: user
    regen = AsyncMock()
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": None})

    assert resp.status_code == 409 and resp.json()["detail"]["code"] == "SOURCE_UNAVAILABLE"
    regen.assert_not_awaited()
