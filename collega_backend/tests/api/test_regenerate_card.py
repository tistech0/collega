"""POST /v1/flash-cards/{id}/regenerate (chantier 1) : texte source toujours disponible."""

from unittest.mock import AsyncMock

import pytest
from sqlalchemy import select

from app.api.v1 import flash_cards as flash_cards_module
from app.deps import require_subscription
from app.models.claude_usage import ClaudeUsage
from app.models.flash_card import FlashCard
from app.services.generation.claude_client import FlashCardData as CardData
from app.services.generation.claude_client import RegenResult
from tests.api_pg import login_as
from tests.factories import make_card, make_college, make_item, make_user

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
    regen = AsyncMock(
        return_value=RegenResult(
            card=CardData("classique", "A", "Q précise ?", "R"),
            input_tokens=500,
            output_tokens=90,
            model="claude-sonnet-5",
        )
    )
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": "trop vague"})

    assert resp.status_code == 200 and resp.json()["data"]["recto"] == "Q précise ?"
    _card, _item, source_text, note = regen.await_args.args
    assert (source_text, note) == ("Le foie {texte source}\n233", "trop vague")
    async with pg_factory() as s:
        saved = await s.get(FlashCard, card.id)
        assert (saved.recto, saved.user_feedback, saved.generation_id) == ("Q précise ?", None, None)
        rows = (await s.execute(select(ClaudeUsage))).scalars().all()
    assert [(r.kind, r.model, r.input_tokens, r.output_tokens, r.user_id, r.college_id, r.job_id) for r in rows] == [
        ("regeneration", "claude-sonnet-5", 500, 90, user.id, card.college_id, None)
    ]


async def test_regenerate_unusable_answer_is_503_but_counted(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory, text="texte source")
    app.dependency_overrides[require_subscription] = lambda: user
    regen = AsyncMock(return_value=RegenResult(card=None, input_tokens=400, output_tokens=12, model="claude-sonnet-5"))
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": None})

    assert resp.status_code == 503
    async with pg_factory() as s:
        rows = (await s.execute(select(ClaudeUsage))).scalars().all()
    assert [(r.kind, r.input_tokens, r.output_tokens) for r in rows] == [("regeneration", 400, 12)]


async def test_regenerate_api_error_records_nothing(pg_client, pg_factory, monkeypatch):
    """Appel sans réponse (APIError) : usage à 0, aucune ligne."""
    from app.main import app

    user, card = await _seed(pg_factory, text="texte source")
    app.dependency_overrides[require_subscription] = lambda: user
    regen = AsyncMock(return_value=RegenResult(card=None, input_tokens=0, output_tokens=0, model="claude-sonnet-5"))
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": None})

    assert resp.status_code == 503
    async with pg_factory() as s:
        assert (await s.execute(select(ClaudeUsage))).scalars().all() == []


async def test_regenerate_without_source_text_is_409(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory, text=None)
    app.dependency_overrides[require_subscription] = lambda: user
    regen = AsyncMock()
    monkeypatch.setattr(flash_cards_module.ClaudeClient, "regenerate_single_card", regen)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/regenerate", json={"user_note": None})

    assert resp.status_code == 409 and resp.json()["detail"]["code"] == "SOURCE_UNAVAILABLE"
    regen.assert_not_awaited()
