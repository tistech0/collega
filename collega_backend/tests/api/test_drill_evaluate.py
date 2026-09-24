"""POST /v1/flash-cards/{id}/evaluate-semantic (chantier 4) : sortie structurée."""

from unittest.mock import AsyncMock

import pytest

from app.api.v1 import drill as drill_module
from app.deps import require_subscription
from app.services.generation.claude_client import ClaudeJsonError, Usage
from tests.api_pg import login_as
from tests.factories import make_card, make_college, make_item, make_user

pytestmark = pytest.mark.pg

_USAGE = Usage(input_tokens=80, output_tokens=15, model="claude-haiku-4-5-20251001")


async def _seed(pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, status="generation_complete")
        item = await make_item(db, college, 304, text="texte")
        card = await make_card(db, item, recto="Terme", verso="Définition", card_type="definition")
        await db.commit()
    return user, card


async def test_evaluate_uses_structured_schema(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory)
    login_as(user)
    app.dependency_overrides[require_subscription] = lambda: user
    ask = AsyncMock(return_value=({"result": "partial", "feedback": "Incomplet."}, _USAGE))
    monkeypatch.setattr(drill_module.ClaudeClient, "ask_json", ask)

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/evaluate-semantic", json={"user_answer": "bof"})

    assert resp.status_code == 200
    assert resp.json()["data"] == {"result": "partial", "feedback": "Incomplet."}
    _prompt, schema = ask.await_args.args
    assert schema is drill_module.EVAL_SCHEMA


async def test_evaluate_unusable_response_is_502(pg_client, pg_factory, monkeypatch):
    from app.main import app

    user, card = await _seed(pg_factory)
    login_as(user)
    app.dependency_overrides[require_subscription] = lambda: user
    monkeypatch.setattr(drill_module.ClaudeClient, "ask_json", AsyncMock(side_effect=ClaudeJsonError("x", _USAGE)))

    resp = await pg_client.post(f"/v1/flash-cards/{card.id}/evaluate-semantic", json={"user_answer": "bof"})

    assert resp.status_code == 502 and resp.json()["detail"]["code"] == "CLAUDE_EVAL_FAILED"
