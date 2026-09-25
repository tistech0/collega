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
        # I4 : 120 s de grâce, réseau mobile instable (retries lents).
        assert token_store.GRACE_S == 120
        assert 60 < await token_redis.ttl(f"refresh:grace:{jti}") <= 120

    async def test_revoque_recemment_est_en_grace(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)
        assert await token_store.refresh_state(jti) == "grace"

    async def test_revoque_hors_grace_est_reutilise(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)
        await token_redis.delete(f"refresh:grace:{jti}")  # simule l'expiration de la grâce
        assert await token_store.refresh_state(jti) == "reused"

    async def test_ttl_minimal_une_seconde(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 0)
        assert 0 < await token_redis.pttl(f"revoked:jti:{jti}") <= 1000

    async def test_revocation_renvoie_l_etat_precedent(self, token_redis):
        jti = _jti()
        assert await token_store.revoke_refresh(jti, 3600) == "active"
        assert await token_store.revoke_refresh(jti, 3600) == "grace"
        await token_redis.delete(f"refresh:grace:{jti}")
        assert await token_store.revoke_refresh(jti, 3600) == "reused"
        # Un jeton déjà révoqué n'est jamais modifié : la grâce n'est pas réarmée.
        assert await token_redis.exists(f"refresh:grace:{jti}") == 0

    async def test_revocation_sans_grace(self, token_redis):
        jti = _jti()
        assert await token_store.revoke_refresh(jti, 3600, grace=False) == "active"
        assert await token_redis.get(f"revoked:jti:{jti}") == b"1"
        assert await token_redis.exists(f"refresh:grace:{jti}") == 0
        assert await token_store.refresh_state(jti) == "reused"

    async def test_seconde_revocation_ne_touche_pas_l_etat(self, token_redis):
        jti = _jti()
        await token_store.revoke_refresh(jti, 3600)
        await token_redis.expire(f"refresh:grace:{jti}", 30)
        await token_redis.expire(f"revoked:jti:{jti}", 100)
        await token_store.revoke_refresh(jti, 3600)
        await token_store.revoke_refresh(jti, 3600, grace=False)
        assert await token_redis.ttl(f"refresh:grace:{jti}") <= 30
        assert await token_redis.ttl(f"revoked:jti:{jti}") <= 100


class TestTokenStoreRedisCoupe:
    async def test_etat_laisse_passer_et_journalise(self, caplog):
        with caplog.at_level(logging.WARNING, logger="app.core.token_store"):
            assert await token_store.refresh_state(_jti()) == "active"
        assert any("Redis" in r.getMessage() for r in caplog.records)

    async def test_revocation_ne_leve_pas_et_journalise(self, caplog):
        jti = _jti()
        with caplog.at_level(logging.WARNING, logger="app.core.token_store"):
            assert await token_store.revoke_refresh(jti, 60) == "active"
        assert any("Redis" in r.getMessage() for r in caplog.records)
        assert all(jti not in r.getMessage() for r in caplog.records)
