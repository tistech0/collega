"""Client Claude p2 (chantier 4, spec § 2-3) : génération, régénération et
évaluation du drill, avec un client Anthropic simulé."""

from __future__ import annotations

import json
import logging
import types
import uuid
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import anthropic
import pytest

from app.api.v1.drill import EVAL_SCHEMA
from app.services.generation import claude_client as cc
from app.services.generation.claude_client import ClaudeClient, ClaudeJsonError, FlashCardData


def _card(type_="classique", rang="A", recto="Q ?", verso="R"):
    return {"type": type_, "rang": rang, "recto": recto, "verso": verso}


def _response(
    payload: dict | str | None,
    *,
    stop_reason: str = "end_turn",
    input_tokens: int = 100,
    output_tokens: int = 50,
    thinking: bool = True,
):
    """Réponse simulée : un bloc de réflexion (vide par défaut en adaptatif) peut
    précéder le bloc texte."""
    content: list = []
    if thinking:
        content.append(SimpleNamespace(type="thinking", thinking="", signature="sig"))
    if payload is not None:
        text = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
        content.append(SimpleNamespace(type="text", text=text))
    return SimpleNamespace(
        content=content,
        stop_reason=stop_reason,
        usage=SimpleNamespace(input_tokens=input_tokens, output_tokens=output_tokens),
    )


def _client(response=None, *, side_effect=None) -> ClaudeClient:
    client = ClaudeClient()
    create = AsyncMock(return_value=response, side_effect=side_effect)
    client._client = SimpleNamespace(messages=SimpleNamespace(create=create))  # type: ignore[assignment]
    return client


def _kwargs(client: ClaudeClient) -> dict:
    return client._client.messages.create.await_args.kwargs  # type: ignore[attr-defined]


# --- Constantes et prompt ---------------------------------------------------


def test_constants():
    assert cc.GENERATION_MODEL == "claude-sonnet-5"
    assert cc.PROMPT_VERSION == "p2"
    assert cc.GENERATION_VERSION == "claude-sonnet-5:p2"


def test_system_prompt_is_spec_text():
    """Le prompt p2 est le texte exact de la spec § 3 (vérifié si la spec est présente)."""
    spec = Path(__file__).resolve().parents[4] / "_bmad-output/planning-artifacts/chantier-4-couts-claude-spec.md"
    if not spec.exists():
        pytest.skip("spec absente")
    section = spec.read_text(encoding="utf-8").split("## 3.", 1)[1]
    block = section.split("```", 2)[1]
    assert block.strip("\n") == cc.GENERATION_SYSTEM_PROMPT


def test_schema_shape():
    card = cc.GENERATION_SCHEMA["properties"]["flashcards"]["items"]
    assert card["properties"]["type"]["enum"] == ["classique", "definition", "cas_clinique"]
    assert card["properties"]["rang"]["enum"] == ["A", "B"]
    assert card["required"] == ["type", "rang", "recto", "verso"]
    assert card["additionalProperties"] is False
    assert cc.GENERATION_SCHEMA["required"] == ["flashcards", "insufficient_text"]
    assert cc.GENERATION_SCHEMA["additionalProperties"] is False


# --- Génération -------------------------------------------------------------


async def test_generate_sends_p2_parameters():
    client = _client(_response({"flashcards": [_card()], "insufficient_text": False}))

    await client.generate_cards(304, "Tumeurs du foie", ["Texte {avec} accolades"])

    kw = _kwargs(client)
    assert kw["model"] == "claude-sonnet-5"
    assert kw["max_tokens"] == 16000
    assert kw["system"] == cc.GENERATION_SYSTEM_PROMPT
    assert kw["thinking"] == {"type": "adaptive"}
    assert kw["output_config"] == {
        "effort": "medium",
        "format": {"type": "json_schema", "schema": cc.GENERATION_SCHEMA},
    }
    for forbidden in ("temperature", "top_p", "top_k"):
        assert forbidden not in kw
    # Pas de préremplissage : un seul message, de l'utilisateur.
    assert kw["messages"] == [
        {
            "role": "user",
            "content": "Item 304 — Tumeurs du foie\n<texte_item>\nTexte {avec} accolades\n</texte_item>",
        }
    ]


async def test_generate_effort_is_configurable():
    client = _client(_response({"flashcards": [], "insufficient_text": False}))
    await client.generate_cards(1, "T", ["x y z"], effort="low")
    assert _kwargs(client)["output_config"]["effort"] == "low"


async def test_generate_cleans_pages_for_prompt(monkeypatch):
    seen = {}

    def fake_clean(pages):
        seen["pages"] = pages
        return "NETTOYÉ"

    monkeypatch.setattr(cc, "clean_for_prompt", fake_clean)
    client = _client(_response({"flashcards": [], "insufficient_text": False}))
    await client.generate_cards(7, "Titre", ["p1", "p2"])
    assert seen["pages"] == ["p1", "p2"]
    assert "<texte_item>\nNETTOYÉ\n</texte_item>" in _kwargs(client)["messages"][0]["content"]


async def test_generate_reads_text_block_after_thinking_block():
    payload = {
        "flashcards": [
            _card("classique", "A", "Q1 ?", "R1"),
            _card("definition", "B", "Terme", "Def"),
            _card("cas_clinique", "A", "Femme de 30 ans… ?", "Diagnostic"),
        ],
        "insufficient_text": False,
    }
    client = _client(_response(payload, input_tokens=1200, output_tokens=800))

    result = await client.generate_cards(12, "Titre", ["texte"])

    assert result.cards == [
        FlashCardData("classique", "A", "Q1 ?", "R1"),
        FlashCardData("definition", "B", "Terme", "Def"),
        FlashCardData("cas_clinique", "A", "Femme de 30 ans… ?", "Diagnostic"),
    ]
    assert (result.input_tokens, result.output_tokens) == (1200, 800)
    assert result.model == "claude-sonnet-5"
    assert result.insufficient_text is False
    assert result.stop_reason == "end_turn"


async def test_generate_without_thinking_block():
    client = _client(_response({"flashcards": [_card()], "insufficient_text": False}, thinking=False))
    result = await client.generate_cards(1, "T", ["texte"])
    assert len(result.cards) == 1


@pytest.mark.parametrize("stop_reason", ["refusal", "max_tokens"])
async def test_generate_refusal_or_max_tokens_gives_no_card_but_usage(stop_reason, caplog):
    payload = '{"flashcards": [{"type": "classique", "rang": "A", "recto": "Q", "ver'
    client = _client(_response(payload, stop_reason=stop_reason, input_tokens=900, output_tokens=16000))

    with caplog.at_level(logging.WARNING, logger=cc.logger.name):
        result = await client.generate_cards(215, "Titre", ["texte"])

    assert result.cards == []
    assert (result.input_tokens, result.output_tokens) == (900, 16000)
    assert result.stop_reason == stop_reason
    assert any("215" in r.getMessage() and r.levelno == logging.WARNING for r in caplog.records)


async def test_generate_refusal_without_text_block():
    client = _client(_response(None, stop_reason="refusal", input_tokens=10, output_tokens=3))
    result = await client.generate_cards(3, "T", ["texte"])
    assert result.cards == [] and (result.input_tokens, result.output_tokens) == (10, 3)


async def test_generate_insufficient_text():
    client = _client(_response({"flashcards": [], "insufficient_text": True}, input_tokens=300, output_tokens=40))
    result = await client.generate_cards(215, "Titre", ["Sommaire"])
    assert result.cards == [] and result.insufficient_text is True
    assert (result.input_tokens, result.output_tokens) == (300, 40)


async def test_generate_insufficient_text_drops_any_card():
    client = _client(_response({"flashcards": [_card()], "insufficient_text": True}))
    result = await client.generate_cards(215, "Titre", ["Sommaire"])
    assert result.cards == [] and result.insufficient_text is True


async def test_generate_truncates_above_40(caplog):
    payload = {"flashcards": [_card(recto=f"Q{i} ?") for i in range(45)], "insufficient_text": False}
    client = _client(_response(payload))

    with caplog.at_level(logging.WARNING, logger=cc.logger.name):
        result = await client.generate_cards(329, "Titre", ["texte"])

    assert len(result.cards) == 40
    assert result.cards[-1].recto == "Q39 ?"
    assert any("329" in r.getMessage() and "45" in r.getMessage() for r in caplog.records)


async def test_generate_unreadable_json_gives_no_card_but_usage():
    client = _client(_response("not json at all", input_tokens=42, output_tokens=7))
    result = await client.generate_cards(320, "Titre", ["texte"])
    assert result.cards == [] and (result.input_tokens, result.output_tokens) == (42, 7)


async def test_generate_skips_invalid_entries():
    payload = {
        "flashcards": [
            _card("invalid"),
            _card(rang="C"),
            _card(recto="   "),
            "pas un objet",
            _card("classique", "B", " Q ok ? ", " R ok "),
        ],
        "insufficient_text": False,
    }
    client = _client(_response(payload))
    result = await client.generate_cards(1, "T", ["texte"])
    assert result.cards == [FlashCardData("classique", "B", "Q ok ?", "R ok")]


@pytest.mark.parametrize("pages", [[], [""], ["   ", "\n"]])
async def test_generate_blank_text_makes_no_call(pages):
    client = _client()
    result = await client.generate_cards(1, "T", pages)
    assert result.cards == [] and (result.input_tokens, result.output_tokens) == (0, 0)
    assert result.stop_reason is None and result.insufficient_text is False
    assert client._client.messages.create.await_count == 0  # type: ignore[attr-defined]


async def test_generate_propagates_api_error():
    client = _client(side_effect=anthropic.APIError("rate limit", request=MagicMock(), body=None))
    with pytest.raises(anthropic.APIError):
        await client.generate_cards(1, "T", ["texte"])


# --- Régénération -----------------------------------------------------------


def _card_row():
    return types.SimpleNamespace(
        id=uuid.uuid4(), item_id=uuid.uuid4(), college_id=uuid.uuid4(),
        card_type="classique", rang="A", recto="Q vague ?", verso="R vague",
    )  # fmt: skip


def _item_row():
    return types.SimpleNamespace(id=uuid.uuid4(), item_number=304, rang="A", chapter_title="Tumeurs du foie")


async def test_regenerate_sends_same_settings_and_one_card_schema():
    client = _client(_response(_card("classique", "B", "Q précise ?", "R précise"), input_tokens=500, output_tokens=90))

    result = await client.regenerate_single_card(_card_row(), _item_row(), "Le foie {source}", "trop vague")

    assert result.card == FlashCardData("classique", "B", "Q précise ?", "R précise")
    assert (result.input_tokens, result.output_tokens, result.model) == (500, 90, "claude-sonnet-5")
    kw = _kwargs(client)
    assert kw["model"] == "claude-sonnet-5"
    assert kw["max_tokens"] == 2000
    assert kw["thinking"] == {"type": "adaptive"}
    assert kw["output_config"] == {
        "effort": "medium",
        "format": {"type": "json_schema", "schema": cc.CARD_SCHEMA},
    }
    assert cc.GENERATION_SCHEMA["properties"]["flashcards"]["items"] == cc.CARD_SCHEMA
    for forbidden in ("temperature", "top_p", "top_k"):
        assert forbidden not in kw
    # Mêmes règles de rédaction que la génération.
    assert "Une seule notion par fiche" in kw["system"]
    content = kw["messages"][0]["content"]
    assert "Q vague ?" in content and "trop vague" in content and "Le foie {source}" in content
    assert "Item 304 — Tumeurs du foie" in content


async def test_regenerate_unusable_response_keeps_usage():
    client = _client(_response("pas du json", input_tokens=400, output_tokens=12))
    result = await client.regenerate_single_card(_card_row(), _item_row(), "texte", None)
    assert result.card is None and (result.input_tokens, result.output_tokens) == (400, 12)


async def test_regenerate_refusal_keeps_usage():
    client = _client(_response(_card(), stop_reason="refusal", input_tokens=50, output_tokens=5))
    result = await client.regenerate_single_card(_card_row(), _item_row(), "texte", None)
    assert result.card is None and (result.input_tokens, result.output_tokens) == (50, 5)


async def test_regenerate_api_error_gives_no_card_no_usage():
    client = _client(side_effect=anthropic.APIError("boom", request=MagicMock(), body=None))
    result = await client.regenerate_single_card(_card_row(), _item_row(), "texte", None)
    assert result.card is None and (result.input_tokens, result.output_tokens) == (0, 0)


async def test_regenerate_blank_source_makes_no_call():
    client = _client()
    result = await client.regenerate_single_card(_card_row(), _item_row(), "  ", None)
    assert result.card is None and client._client.messages.create.await_count == 0  # type: ignore[attr-defined]


# --- Évaluation du drill (Haiku) ----------------------------------------------

_EVAL_SCHEMA = EVAL_SCHEMA


async def test_ask_json_uses_haiku_structured_output():
    client = _client(
        _response({"result": "partial", "feedback": "Incomplet."}, thinking=False, input_tokens=80, output_tokens=15)
    )

    data, usage = await client.ask_json("prompt", _EVAL_SCHEMA)

    assert data == {"result": "partial", "feedback": "Incomplet."}
    assert usage == cc.Usage(input_tokens=80, output_tokens=15, model="claude-haiku-4-5-20251001")
    kw = _kwargs(client)
    assert kw["model"] == "claude-haiku-4-5-20251001"
    assert kw["output_config"] == {"format": {"type": "json_schema", "schema": _EVAL_SCHEMA}}
    assert "thinking" not in kw and "temperature" not in kw
    assert kw["messages"] == [{"role": "user", "content": "prompt"}]


async def test_ask_json_unreadable_raises_with_usage():
    client = _client(_response("pas du json", thinking=False, input_tokens=70, output_tokens=9))
    with pytest.raises(ClaudeJsonError) as exc:
        await client.ask_json("prompt", _EVAL_SCHEMA)
    assert isinstance(exc.value, ValueError)
    assert exc.value.usage == cc.Usage(input_tokens=70, output_tokens=9, model="claude-haiku-4-5-20251001")


async def test_ask_json_refusal_raises_with_usage():
    client = _client(_response(None, stop_reason="refusal", thinking=False, input_tokens=5, output_tokens=1))
    with pytest.raises(ClaudeJsonError) as exc:
        await client.ask_json("prompt", _EVAL_SCHEMA)
    assert exc.value.usage.input_tokens == 5
