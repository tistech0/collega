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


@pytest.fixture(autouse=True)
def _readable_pdf(monkeypatch):
    """Ces tests exercent l'assemblage des morceaux (octets factices) ; l'ouverture
    du PDF (422 PDF_DAMAGED) est testée à part dans test_pdf_damaged.py."""
    monkeypatch.setattr(colleges_module, "assert_pdf_readable", AsyncMock(return_value=1))


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


class TestParts:
    async def test_put_part_204_et_marque(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(
            f"/v1/colleges/import/{st.upload_id}/parts/0",
            content=b"%PDF",
            headers={"Content-Type": "application/octet-stream"},
        )
        assert resp.status_code == 204
        assert (await store.get(st.upload_id)).received == {0}
        assert store.part_path(st.upload_id, 0).read_bytes() == b"%PDF"

    async def test_put_part_taille_incorrecte_422(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(f"/v1/colleges/import/{st.upload_id}/parts/0", content=b"%PDF-xx")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_PART"
        assert (await store.get(st.upload_id)).received == set()

    async def test_put_part_index_hors_bornes_422(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(f"/v1/colleges/import/{st.upload_id}/parts/3", content=b"abcd")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_PART"

    async def test_put_part_upload_inconnu_404(self, client, app_with_store):
        resp = await client.put(f"/v1/colleges/import/{uuid.uuid4()}/parts/0", content=b"abcd")
        assert resp.status_code == 404


def _pdf_part(size: int) -> bytes:
    return b"%PDF-" + b"x" * (size - 5)


async def _upload_all(store, st, first: bytes | None = None):
    for n in range(st.parts_total):
        size = st.expected_part_size(n)
        data = b"y" * size
        if n == 0:
            data = first if first is not None else _pdf_part(size)

        async def gen(d=data):
            yield d

        await store.write_part(st, n, gen())


class TestComplete:
    async def test_complete_incomplet_409_avec_missing(self, client, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        st = await store.create(user.id, 34, 10)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 409
        assert resp.json()["detail"] == {"code": "UPLOAD_INCOMPLETE", "message": "Morceaux manquants", "missing": [0]}
        assert await store.get(st.upload_id) is not None  # état conservé

    async def test_complete_autre_user_404(self, client, mock_db, app_with_store, store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        st = await store.create(uuid.uuid4(), 34, 10)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 404

    async def test_complete_magic_invalide_422_et_purge(self, client, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st, first=b"NOTAPDF!!!")
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_FILE_TYPE"
        assert await store.get(st.upload_id) is None
        assert not store.part_path(st.upload_id, 0).parent.exists()

    async def test_complete_appelle_le_chemin_commun_et_purge(
        self, client, mock_db, app_with_store, store, monkeypatch, tmp_path
    ):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)
        captured = {}

        async def fake_start(db, u, ref_id, pdf_file_path):
            captured["ref_id"] = ref_id
            captured["bytes"] = pdf_file_path.read_bytes()
            from app.schemas.college import ImportCollegeResponseData

            return ImportCollegeResponseData(college_id="c", job_id="j", status="pending")

        monkeypatch.setattr(colleges_module, "_start_import_from_file", fake_start)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 202 and resp.json()["data"] == {
            "college_id": "c",
            "job_id": "j",
            "status": "pending",
        }
        assert captured["ref_id"] == 34 and captured["bytes"].startswith(b"%PDF-") and len(captured["bytes"]) == 10
        assert await store.get(st.upload_id) is None
        assert not store.part_path(st.upload_id, 0).parent.exists()

    async def test_complete_pdf_endommage_422_purge_sans_import(
        self, client, mock_db, app_with_store, store, monkeypatch, tmp_path
    ):
        from app.services.ocr.pdf_check import pdf_damaged

        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        monkeypatch.setattr(colleges_module, "assert_pdf_readable", AsyncMock(side_effect=pdf_damaged()))
        start = AsyncMock()
        monkeypatch.setattr(colleges_module, "_start_import_from_file", start)
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)

        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")

        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "PDF_DAMAGED"
        start.assert_not_awaited()
        assert await store.get(st.upload_id) is None
        assert not store.part_path(st.upload_id, 0).parent.exists()
        assert list(tmp_path.glob("incoming_*.pdf")) == []

    async def test_double_complete_le_second_404(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)
        await store.claim(st.upload_id)  # simule un complete concurrent qui a gagné
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 404  # l'état a disparu pour le perdant → UPLOAD_NOT_FOUND

    async def test_claim_perdu_409_job_in_progress(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        """Les deux complete ont lu l'état, un seul gagne le DEL : le perdant reçoit 409."""
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)

        real_get = store.get
        real_claim = store.claim

        async def losing_claim(upload_id):
            await real_claim(upload_id)  # le concurrent gagne juste avant nous
            return await real_claim(upload_id)

        monkeypatch.setattr(store, "get", real_get)
        monkeypatch.setattr(store, "claim", losing_claim)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 409 and resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"

    async def test_enqueue_ko_503_restaure_l_etat(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)

        async def failing_start(db, u, ref_id, pdf_file_path):
            pdf_file_path.unlink(missing_ok=True)
            from fastapi import HTTPException

            raise HTTPException(status_code=503, detail={"code": "QUEUE_UNAVAILABLE", "message": "x"})

        monkeypatch.setattr(colleges_module, "_start_import_from_file", failing_start)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 503
        again = await store.get(st.upload_id)
        assert again is not None and again.is_complete  # morceaux + clé restaurés
        assert store.part_path(st.upload_id, 0).exists()

    async def test_complete_reel_renomme_et_enqueue(
        self, client, mock_db, app_with_store, store, monkeypatch, tmp_path
    ):
        """Chemin complet sans fake : assemblage → _start_import_from_file → {college.id}_{job_id}.pdf enqueué."""
        from unittest.mock import patch

        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)

        college_id = uuid.uuid4()
        college = types.SimpleNamespace(
            id=college_id, user_id=user.id, college_ref_id=34, status="processing", reload_count=0
        )
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalar_one_or_none=MagicMock(return_value=college)),  # SELECT College
                MagicMock(scalar_one_or_none=MagicMock(return_value=None)),  # SELECT GenerationJob
            ]
        )
        mock_pool = AsyncMock()
        mock_pool.enqueue_job = AsyncMock(return_value=MagicMock(job_id="arq-1"))
        with patch("arq.create_pool", AsyncMock(return_value=mock_pool)):
            resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")

        assert resp.status_code == 202, resp.text
        job_id = resp.json()["data"]["job_id"]
        final = tmp_path / f"{college_id}_{job_id}.pdf"
        assert final.read_bytes().startswith(b"%PDF-") and final.stat().st_size == 10
        mock_pool.enqueue_job.assert_awaited_once_with("process_college_ocr", str(college_id), job_id, str(final))
        assert not (tmp_path / f"incoming_{st.upload_id}.pdf").exists()
        assert await store.get(st.upload_id) is None
