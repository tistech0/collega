"""Tests ChunkedUploadStore — état Redis + morceaux disque (Story 7.11)."""

from __future__ import annotations

import os
import time
import uuid
from datetime import timedelta

import pytest

from app.services.upload.chunked_upload import (
    PART_SIZE,
    UPLOAD_TTL_SECONDS,
    ChunkedUploadStore,
    InvalidPartIndex,
    PartSizeError,
)
from tests.fakes.fake_redis import FakeRedis


async def _chunks(*parts: bytes):
    for p in parts:
        yield p


@pytest.fixture
def store(tmp_path):
    return ChunkedUploadStore(FakeRedis(), tmp_path)


class TestCreateGet:
    async def test_create_calcule_parts_total_et_pose_ttl(self, store):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE * 2 + 1)
        assert st.parts_total == 3 and st.part_size == PART_SIZE and st.received == set()
        assert store._redis.ttl[f"upload:{st.upload_id}"] == UPLOAD_TTL_SECONDS
        assert st.expected_part_size(0) == PART_SIZE and st.expected_part_size(2) == 1

    async def test_get_inconnu_renvoie_none(self, store):
        assert await store.get(str(uuid.uuid4())) is None

    async def test_get_relit_les_types(self, store):
        user = uuid.uuid4()
        created = await store.create(user, 3, 100)
        st = await store.get(created.upload_id)
        assert st is not None and st.user_id == str(user) and st.ref_id == 3 and st.size_bytes == 100
        assert st.expires_at == created.created_at + timedelta(seconds=UPLOAD_TTL_SECONDS)


class TestParts:
    async def test_write_part_ecrit_et_marque_recu(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        await store.write_part(st, 0, _chunks(b"%PDF-", b"12345"))
        assert store.part_path(st.upload_id, 0).read_bytes() == b"%PDF-12345"
        assert (await store.get(st.upload_id)).received == {0}
        assert not store.part_path(st.upload_id, 0).with_suffix(".tmp").exists()

    async def test_write_part_taille_incorrecte_leve_et_ne_marque_pas(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        with pytest.raises(PartSizeError):
            await store.write_part(st, 0, _chunks(b"abc"))
        assert (await store.get(st.upload_id)).received == set()
        assert not store.part_path(st.upload_id, 0).exists()

    async def test_write_part_index_hors_bornes(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        with pytest.raises(InvalidPartIndex):
            await store.write_part(st, 1, _chunks(b"x"))

    async def test_write_part_idempotent(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"aaaa"))
        await store.write_part(st, 0, _chunks(b"bbbb"))
        assert store.part_path(st.upload_id, 0).read_bytes() == b"bbbb"


class TestClaimAssemble:
    async def test_claim_gagne_une_seule_fois(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        assert (await store.claim(st.upload_id)) is not None
        assert (await store.claim(st.upload_id)) is None

    async def test_restore_remet_l_etat(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"abcd"))
        claimed = await store.claim(st.upload_id)
        await store.restore(claimed)
        again = await store.get(st.upload_id)
        assert again is not None and again.received == {0}

    async def test_assemble_concatene_dans_l_ordre(self, store, tmp_path):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE + 3)
        await store.write_part(st, 1, _chunks(b"END"))
        await store.write_part(st, 0, _chunks(b"%PDF-" + b"x" * (PART_SIZE - 5)))
        dest = tmp_path / "out.pdf"
        assert store.assemble(await store.get(st.upload_id), dest) == PART_SIZE + 3
        data = dest.read_bytes()
        assert data.startswith(b"%PDF-") and data.endswith(b"END")

    async def test_purge_supprime_dossier_et_cles(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"abcd"))
        await store.claim(st.upload_id)
        store.purge(st.upload_id)
        assert not store.part_path(st.upload_id, 0).parent.exists()

    def test_stale_dirs_par_mtime(self, store, tmp_path):
        old = tmp_path / "uploads" / "old"
        old.mkdir(parents=True)
        os.utime(old, (time.time() - 90000, time.time() - 90000))
        fresh = tmp_path / "uploads" / "fresh"
        fresh.mkdir()
        assert store.stale_dirs(timedelta(hours=24)) == [old]
