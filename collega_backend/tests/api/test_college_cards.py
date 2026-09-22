"""Story 8.3 — GET /v1/colleges/{college_id}/cards : toutes les fiches d'un collège.

L'app synchronise ainsi toutes les fiches en local (session du jour mixte, hors-ligne)
au lieu d'attendre l'ouverture de chaque item.
"""
import uuid
from unittest.mock import AsyncMock, MagicMock

from httpx import AsyncClient

from app.deps import get_current_user
from tests.api.test_colleges import _make_card, _make_college, _make_item, _make_user


def _scalars(rows):
    return MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=rows))))


class TestListCollegeCards:
    async def test_non_authentifie_retourne_401(self, client: AsyncClient):
        resp = await client.get(f"/v1/colleges/{uuid.uuid4()}/cards")
        assert resp.status_code == 401

    async def test_college_autre_user_retourne_404(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3)  # autre propriétaire
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/cards")
        finally:
            app.dependency_overrides.pop(get_current_user, None)
        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_generation_non_complete_retourne_409(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id, status="processing")
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/cards")
        finally:
            app.dependency_overrides.pop(get_current_user, None)
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "GENERATION_NOT_COMPLETE"

    async def test_retourne_toutes_les_fiches_de_tous_les_items(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id)
        item_1, item_2 = _make_item(college.id, item_number=290), _make_item(college.id, item_number=291)
        cards = [
            _make_card(item_1.id, college.id, user.id, rang="A"),
            _make_card(item_1.id, college.id, user.id, rang="B"),
            _make_card(item_2.id, college.id, user.id, rang="A", card_type="classique"),
        ]
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=_scalars(cards))
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/cards")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 3
        assert {c["item_id"] for c in body["data"]} == {str(item_1.id), str(item_2.id)}
        first = body["data"][0]
        assert set(first) >= {"id", "item_id", "college_id", "card_type", "rang", "recto", "verso",
                              "ocr_confidence_score", "low_confidence"}

    async def test_requete_filtre_sur_le_college(self, client: AsyncClient, mock_db):
        """La requête ne lit que les fiches de ce collège (pas celles des autres users)."""
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id)
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(return_value=_scalars([]))
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/cards")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        assert resp.json() == {"data": [], "total": 0}
        stmt = mock_db.execute.await_args.args[0]
        compiled = str(stmt.compile(compile_kwargs={"literal_binds": True}))
        assert "flash_cards.college_id" in compiled
        assert college.id.hex in compiled.replace("-", "")


class TestUserFeedbackRenvoye:
    """Bug trouvé en 8.3 : user_feedback n'était jamais renvoyé → l'app effaçait
    le pouce local à chaque synchronisation (valeur null écrite dans Drift)."""

    async def _get(self, client, mock_db, path_fn):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id)
        item = _make_item(college.id)
        card = _make_card(item.id, college.id, user.id)
        card.user_feedback = "positive"
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(side_effect=[college, item])
        mock_db.execute = AsyncMock(return_value=_scalars([card]))
        try:
            return await client.get(path_fn(college, item))
        finally:
            app.dependency_overrides.pop(get_current_user, None)

    async def test_cards_du_college(self, client: AsyncClient, mock_db):
        resp = await self._get(client, mock_db, lambda c, i: f"/v1/colleges/{c.id}/cards")
        assert resp.json()["data"][0]["user_feedback"] == "positive"

    async def test_cards_d_un_item(self, client: AsyncClient, mock_db):
        resp = await self._get(client, mock_db, lambda c, i: f"/v1/colleges/{c.id}/items/{i.id}/cards")
        assert resp.json()["data"][0]["user_feedback"] == "positive"
