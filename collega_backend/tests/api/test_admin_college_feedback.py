"""Tests GET /v1/admin/colleges/{id}/feedback — avis de l'utilisatrice (pouces du drill,
`flash_cards.user_feedback`) joints à la fiche (Story 7.8 AC3, chantier 5 R3), sur Postgres réel."""

from __future__ import annotations

import uuid

import pytest

from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_item, make_user

pytestmark = pytest.mark.pg


class TestGetCollegeFeedback:
    async def test_401_without_credentials(self, pg_client):
        resp = await pg_client.get(f"/v1/admin/colleges/{uuid.uuid4()}/feedback")
        assert resp.status_code == 401

    async def test_404_for_unknown_college(self, pg_client):
        resp = await pg_client.get(f"/v1/admin/colleges/{uuid.uuid4()}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_returns_feedback_joined_to_card_sorted_by_item(self, pg_client, pg_factory):
        async with pg_factory() as db:
            user = await make_user(db)
            college = await make_college(db, user)
            item_12 = await make_item(db, college, 12, rang="B")
            item_3 = await make_item(db, college, 3, rang="A")
            card_ok = await make_card(
                db, item_12, recto="Bonne question ?", verso="Bonne réponse", card_type="definition"
            )
            card_ko = await make_card(db, item_3, recto="Question peu claire ?", verso="Réponse")
            card_ko.user_feedback = "negative"
            card_ok.user_feedback = "positive"
            await make_card(db, item_3, recto="Sans avis ?")  # user_feedback NULL : exclue
            # Fiche d'un autre collège : exclue
            other = await make_college(db, await make_user(db), ref_id=35)
            other_card = await make_card(db, await make_item(db, other, 1))
            other_card.user_feedback = "negative"
            await db.commit()

        resp = await pg_client.get(f"/v1/admin/colleges/{college.id}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 2
        data = body["data"]
        # Tri par numéro d'item : l'item 3 (avis négatif) avant l'item 12
        assert data[0] == {
            "flash_card_id": str(card_ko.id),
            "item_number": 3,
            "user_email": user.email,
            "feedback": "negative",
            "is_pertinent": False,
            "recto": "Question peu claire ?",
            "verso": "Réponse",
            "card_type": "classique",
            "rang": "A",
        }
        assert data[1]["flash_card_id"] == str(card_ok.id)
        assert data[1]["item_number"] == 12
        assert data[1]["feedback"] == "positive"
        assert data[1]["is_pertinent"] is True
        assert data[1]["card_type"] == "definition"
        assert data[1]["rang"] == "B"

    async def test_empty_returns_empty_list(self, pg_client, pg_factory):
        async with pg_factory() as db:
            college = await make_college(db, await make_user(db))
            await make_card(db, await make_item(db, college, 1))  # aucune fiche notée
            await db.commit()

        resp = await pg_client.get(f"/v1/admin/colleges/{college.id}/feedback", auth=ADMIN_AUTH)
        assert resp.status_code == 200
        assert resp.json() == {"data": [], "total": 0}
