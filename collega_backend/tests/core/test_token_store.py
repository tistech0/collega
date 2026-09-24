"""Magasin de révocation des refresh tokens (chantier 2 § 2) — Redis réel."""

from __future__ import annotations

import logging
import uuid

from app.core import token_store


def _jti() -> str:
    return uuid.uuid4().hex


class TestTokenStoreRedisReel:
    async def test_jeton_inconnu_est_actif(self, token_redis):
        assert await token_store.refresh_state(_jti()) == "active"

    async def test_revocation_pose_les_deux_cles_avec_ttl(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)

        assert await token_redis.get(f"revoked:jti:{jti}") == b"1"
        assert 3590 <= await token_redis.ttl(f"revoked:jti:{jti}") <= 3600
        assert await token_redis.get(f"refresh:grace:{jti}") == b"1"
        assert 0 < await token_redis.ttl(f"refresh:grace:{jti}") <= token_store.GRACE_S

    async def test_revoque_recemment_est_en_grace(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)
        assert await token_store.refresh_state(jti) == "grace"

    async def test_revoque_hors_grace_est_reutilise(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)
        await token_redis.delete(f"refresh:grace:{jti}")  # simule l'expiration des 60 s
        assert await token_store.refresh_state(jti) == "reused"

    async def test_ttl_minimal_une_seconde(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 0)
        assert await token_redis.ttl(f"revoked:jti:{jti}") >= 0


class TestTokenStoreRedisCoupe:
    async def test_etat_laisse_passer_et_journalise(self, caplog):
        with caplog.at_level(logging.WARNING, logger="app.core.token_store"):
            assert await token_store.refresh_state(_jti()) == "active"
        assert any("Redis" in r.getMessage() for r in caplog.records)

    async def test_revocation_ne_leve_pas_et_journalise(self, caplog):
        jti = _jti()
        with caplog.at_level(logging.WARNING, logger="app.core.token_store"):
            await token_store.revoke_refresh(jti, 60)
        assert any("Redis" in r.getMessage() for r in caplog.records)
        assert all(jti not in r.getMessage() for r in caplog.records)
