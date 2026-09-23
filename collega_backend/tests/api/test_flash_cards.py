"""Tests endpoints feedback, suppression et régénération de fiches — FR19, FR20, FR21, FR23."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import AsyncClient

from app.deps import get_current_user, require_subscription


def _make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="test@example.com",
        is_subscribed=True,
        is_beta=False,
        apns_token=None,
    )


def _make_item(item_id=None, item_number=232, rang="A", ocr_text="Texte OCR médical"):
    return types.SimpleNamespace(
        id=item_id or uuid.uuid4(),
        item_number=item_number,
        rang=rang,
        ocr_text=ocr_text,
    )


def _make_card(card_id=None, item_id=None, college_id=None, user_id=None):
    return types.SimpleNamespace(
        id=card_id or uuid.uuid4(),
        item_id=item_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        user_id=user_id or uuid.uuid4(),
        card_type="classique",
        rang="A",
        recto="Question initiale ?",
        verso="Réponse initiale",
        ocr_confidence_score=0.85,
        low_confidence=False,
        user_feedback=None,
    )


class TestSubmitFeedback:
    async def test_feedback_positif_ok(self, client: AsyncClient, mock_db):
        """POST /v1/flash-cards/{id}/feedback avec feedback=positive → 200."""
        from app.main import app

        user = _make_user()
        card = _make_card(user_id=user.id)
        mock_db.get = AsyncMock(return_value=card)

        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.post(
            f"/v1/flash-cards/{card.id}/feedback",
            json={"feedback": "positive"},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["feedback"] == "positive"

        app.dependency_overrides.clear()

    async def test_feedback_card_autre_user_retourne_404(self, client: AsyncClient, mock_db):
        """POST .../feedback quand card.user_id != current_user.id → 404."""
        from app.main import app

        user = _make_user()
        card = _make_card(user_id=uuid.uuid4())  # autre user
        mock_db.get = AsyncMock(return_value=card)

        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.post(
            f"/v1/flash-cards/{card.id}/feedback",
            json={"feedback": "negative"},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 404

        app.dependency_overrides.clear()

    async def test_feedback_card_introuvable_retourne_404(self, client: AsyncClient, mock_db):
        """POST .../feedback quand card non trouvée → 404."""
        from app.main import app

        user = _make_user()
        mock_db.get = AsyncMock(return_value=None)

        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.post(
            f"/v1/flash-cards/{uuid.uuid4()}/feedback",
            json={"feedback": "positive"},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 404

        app.dependency_overrides.clear()


class TestDeleteCard:
    async def test_delete_card_ok(self, client: AsyncClient, mock_db):
        """DELETE /v1/flash-cards/{id} → 204."""
        from app.main import app

        user = _make_user()
        card = _make_card(user_id=user.id)
        mock_db.get = AsyncMock(return_value=card)
        mock_db.delete = AsyncMock()

        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.delete(
            f"/v1/flash-cards/{card.id}",
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 204

        app.dependency_overrides.clear()

    async def test_delete_card_introuvable_retourne_404(self, client: AsyncClient, mock_db):
        """DELETE .../cards/{id} quand card non trouvée → 404."""
        from app.main import app

        user = _make_user()
        mock_db.get = AsyncMock(return_value=None)

        app.dependency_overrides[require_subscription] = lambda: user

        resp = await client.delete(
            f"/v1/flash-cards/{uuid.uuid4()}",
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 404

        app.dependency_overrides.clear()


class TestRegenerateCard:
    async def test_regenerate_card_ok(self, client: AsyncClient, mock_db):
        """POST .../regenerate avec ClaudeClient mocké → 200 avec nouvelle fiche."""
        from app.main import app
        from app.schemas.college import FlashCardData

        user = _make_user()
        card = _make_card(user_id=user.id)
        item = _make_item(item_id=card.item_id)

        def _get_side_effect(model, pk):
            from app.models.flash_card import FlashCard
            from app.models.item import Item

            if model is FlashCard or (isinstance(model, type) and issubclass(model, FlashCard)):
                return card
            return item

        mock_db.get = AsyncMock(side_effect=_get_side_effect)
        mock_db.refresh = AsyncMock()

        new_card_data = FlashCardData(
            id=str(card.id),
            item_id=str(card.item_id),
            college_id=str(card.college_id),
            card_type="classique",
            rang="A",
            recto="Nouvelle question ?",
            verso="Nouvelle réponse",
            ocr_confidence_score=0.85,
            low_confidence=False,
        )

        app.dependency_overrides[require_subscription] = lambda: user

        with patch(
            "app.api.v1.flash_cards.ClaudeClient.regenerate_single_card",
            new=AsyncMock(return_value=new_card_data),
        ):
            resp = await client.post(
                f"/v1/flash-cards/{card.id}/regenerate",
                json={"user_note": "La réponse était trop vague"},
                headers={"Authorization": "Bearer token"},
            )

        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["recto"] == "Nouvelle question ?"
        assert data["verso"] == "Nouvelle réponse"

        app.dependency_overrides.clear()


class TestRegisterApnsToken:
    async def test_register_token_ok(self, client: AsyncClient, mock_db):
        """POST /v1/notifications/apns-token → 200 registered=True."""
        from app.main import app

        user = _make_user()
        app.dependency_overrides[get_current_user] = lambda: user

        resp = await client.post(
            "/v1/notifications/apns-token",
            json={"token": "ab12" * 16},
            headers={"Authorization": "Bearer token"},
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["registered"] is True
        assert user.apns_token == "ab12" * 16

        app.dependency_overrides.clear()
