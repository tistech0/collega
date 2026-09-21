"""Cron de purge des uploads par morceaux orphelins (Story 7.11)."""
from __future__ import annotations

import os
import time
import uuid

from app.services.upload.chunked_upload import ChunkedUploadStore
from app.workers import cleanup_worker
from tests.fakes.fake_redis import FakeRedis


async def test_purge_dossiers_sans_cle_ou_trop_vieux(tmp_path, monkeypatch):
    monkeypatch.setattr(cleanup_worker.settings, "pdf_storage_path", str(tmp_path))
    redis = FakeRedis()
    store = ChunkedUploadStore(redis, tmp_path)
    live = await store.create(uuid.uuid4(), 34, 10)  # clé présente, récent → gardé
    (tmp_path / "uploads" / live.upload_id).mkdir(parents=True)
    orphan = tmp_path / "uploads" / str(uuid.uuid4())  # pas de clé → purgé
    orphan.mkdir()
    old = await store.create(uuid.uuid4(), 34, 10)  # clé présente mais > 24 h → purgé
    old_dir = tmp_path / "uploads" / old.upload_id
    old_dir.mkdir()
    os.utime(old_dir, (time.time() - 90000, time.time() - 90000))

    removed = await cleanup_worker.cleanup_stale_uploads({"redis": redis})

    assert removed == 2
    assert (tmp_path / "uploads" / live.upload_id).exists()
    assert not orphan.exists() and not old_dir.exists()


async def test_sans_dossier_uploads_renvoie_zero(tmp_path, monkeypatch):
    monkeypatch.setattr(cleanup_worker.settings, "pdf_storage_path", str(tmp_path))
    assert await cleanup_worker.cleanup_stale_uploads({"redis": FakeRedis()}) == 0
