"""Tests du service ClaudeClient — génération de flashcards via API Anthropic."""

from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.generation.claude_client import ClaudeClient


def make_item(ocr_text: str | None = "Item 1 Rang A\nContenu médical test."):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        item_number=1,
        rang="A",
        ocr_text=ocr_text,
    )


def make_mock_response(json_text: str, input_tokens: int = 100, output_tokens: int = 50) -> MagicMock:
    mock_response = MagicMock()
    mock_response.content = [MagicMock(text=json_text)]
    # Story 7.8 : le SDK Anthropic expose response.usage.{input,output}_tokens
    mock_response.usage = MagicMock(input_tokens=input_tokens, output_tokens=output_tokens)
    return mock_response


class TestClaudeClientGenerateCards:
    async def test_returns_cards_on_valid_json(self):
        """AC#1 — retourne des FlashCardData + usage sur réponse JSON valide."""
        json_text = '{"flashcards": [{"type": "classique", "recto": "Q?", "verso": "R"}, {"type": "definition", "recto": "Terme", "verso": "Def"}]}'

        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(
                return_value=make_mock_response(json_text, input_tokens=120, output_tokens=80)
            )
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item()
            result = await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")

        assert len(result.cards) == 2
        assert result.cards[0].card_type == "classique"
        assert result.cards[0].recto == "Q?"
        assert result.cards[0].verso == "R"
        assert result.cards[1].card_type == "definition"
        # Story 7.8 — usage capturé
        assert result.input_tokens == 120
        assert result.output_tokens == 80

    async def test_returns_empty_on_none_ocr_text(self):
        """AC#1 — retourne cards=[] + usage 0/0 sans appel Claude si ocr_text est None."""
        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item(ocr_text=None)
            result = await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")

        assert result.cards == []
        assert result.input_tokens == 0
        assert result.output_tokens == 0
        mock_client.messages.create.assert_not_called()

    async def test_returns_empty_on_empty_ocr_text(self):
        """AC#1 — retourne cards=[] + usage 0/0 sans appel Claude si ocr_text est vide."""
        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item(ocr_text="")
            result = await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")

        assert result.cards == []
        assert result.input_tokens == 0
        assert result.output_tokens == 0
        mock_client.messages.create.assert_not_called()

    async def test_captures_usage_even_when_json_invalid(self):
        """AC#1 (cœur 7.8) — cards=[] mais usage CAPTURÉ si le JSON est invalide
        (les tokens ont été facturés malgré le parsing raté)."""
        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(
                return_value=make_mock_response("not json at all", input_tokens=42, output_tokens=7)
            )
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item()
            result = await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")

        assert result.cards == []
        assert result.input_tokens == 42
        assert result.output_tokens == 7

    async def test_skips_cards_with_invalid_type(self):
        """AC#1 — ignore les flashcards avec un type inconnu."""
        json_text = '{"flashcards": [{"type": "invalid", "recto": "Q?", "verso": "R"}, {"type": "classique", "recto": "Q2?", "verso": "R2"}]}'

        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(return_value=make_mock_response(json_text))
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item()
            result = await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")

        assert len(result.cards) == 1
        assert result.cards[0].card_type == "classique"

    async def test_propagates_api_error(self):
        """AC#3 — propage APIError pour que le worker marque failed (aucun usage)."""
        import anthropic as _anthropic

        with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(
                side_effect=_anthropic.APIError("rate limit", request=MagicMock(), body=None)
            )
            mock_cls.return_value = mock_client

            client = ClaudeClient()
            item = make_item()

            with pytest.raises(_anthropic.APIError):
                await client.generate_cards(item.item_number, item.rang, item.ocr_text or "")


async def test_generate_cards_from_text_uses_versioned_model():
    from types import SimpleNamespace
    from unittest.mock import AsyncMock

    from app.services.generation import claude_client as cc

    client = cc.ClaudeClient()
    response = SimpleNamespace(
        usage=SimpleNamespace(input_tokens=100, output_tokens=20),
        content=[SimpleNamespace(text='{"flashcards":[{"type":"classique","recto":"Q ?","verso":"R"}]}')],
    )
    client._client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))

    result = await client.generate_cards(304, "B", "Texte {avec} accolades")

    assert [c.recto for c in result.cards] == ["Q ?"]
    assert (result.input_tokens, result.output_tokens) == (100, 20)
    kwargs = client._client.messages.create.await_args.kwargs
    assert kwargs["model"] == cc.GENERATION_MODEL
    assert "Texte {avec} accolades" in kwargs["messages"][0]["content"]
    assert cc.GENERATION_VERSION == "claude-sonnet-4-6:p1"


async def test_blank_text_makes_no_call():
    from types import SimpleNamespace
    from unittest.mock import AsyncMock

    from app.services.generation import claude_client as cc

    client = cc.ClaudeClient()
    client._client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock()))
    result = await client.generate_cards(1, "A", "   ")
    assert result.cards == [] and client._client.messages.create.await_count == 0
