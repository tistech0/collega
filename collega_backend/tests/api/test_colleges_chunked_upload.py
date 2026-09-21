"""Tests upload par morceaux — init / status / parts / complete (Story 7.11)."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.api.v1 import colleges as colleges_module
from app.deps import require_subscription
from app.services.upload.chunked_upload import PART_SIZE, ChunkedUploadStore
from tests.fakes.fake_redis import FakeRedis


def _make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(),
        email="t@example.com",
        is_subscribed=True,
        is_beta=False,
        monthly_reloads=0,
        monthly_reloads_reset_at=None,
    )


@pytest.fixture
def store(tmp_path):
    return ChunkedUploadStore(FakeRedis(), tmp_path)


@pytest.fixture
def app_with_store(store):
    from app.main import app

    async def _override():
        yield store

    app.dependency_overrides[colleges_module.get_upload_store] = _override
    yield app
    app.dependency_overrides.pop(colleges_module.get_upload_store, None)
    app.dependency_overrides.pop(require_subscription, None)


def _no_college(mock_db):
    # _assert_import_allowed : SELECT College → None (premier import)
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))


class TestInit:
    async def test_init_cree_un_upload(self, client: AsyncClient, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        _no_college(mock_db)

        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": PART_SIZE * 2 + 5})

        assert resp.status_code == 201, resp.text
        data = resp.json()["data"]
        assert data["part_size"] == PART_SIZE and data["parts_total"] == 3
        st = await store.get(data["upload_id"])
        assert st is not None and st.user_id == str(user.id) and st.ref_id == 34

    async def test_init_trop_gros_413(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        _no_college(mock_db)
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 500 * 1024 * 1024 + 1})
        assert resp.status_code == 413 and resp.json()["detail"]["code"] == "FILE_TOO_LARGE"

    async def test_init_taille_nulle_422(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        _no_college(mock_db)
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 0})
        assert resp.status_code == 422

    async def test_init_ref_id_invalide_422(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        resp = await client.post("/v1/colleges/99/import/init", json={"size_bytes": 10})
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_REF_ID"

    async def test_init_job_en_cours_409_sans_ecriture(self, client, mock_db, app_with_store, store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        college = types.SimpleNamespace(id=uuid.uuid4(), status="processing", reload_count=0)
        job = types.SimpleNamespace(id=uuid.uuid4())
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
                MagicMock(scalar_one_or_none=MagicMock(return_value=job)),
            ]
        )
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 10})
        assert resp.status_code == 409 and resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"
        assert store._redis.hashes == {}


class TestStatus:
    async def test_status_inconnu_404(self, client, app_with_store):
        resp = await client.get(f"/v1/colleges/import/{uuid.uuid4()}")
        assert resp.status_code == 404 and resp.json()["detail"]["code"] == "UPLOAD_NOT_FOUND"

    async def test_status_renvoie_les_morceaux_recus(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE + 1)
        await store._redis.sadd(f"upload:{st.upload_id}:parts", 1)
        resp = await client.get(f"/v1/colleges/import/{st.upload_id}")
        assert resp.status_code == 200
        assert resp.json()["data"] == {
            "received": [1],
            "parts_total": 2,
            "part_size": PART_SIZE,
            "size_bytes": PART_SIZE + 1,
            "expires_at": st.expires_at.isoformat(),
        }
