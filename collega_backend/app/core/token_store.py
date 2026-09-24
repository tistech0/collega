"""Révocation des refresh tokens dans Redis (chantier 2 § 2).

- `revoked:jti:{jti}` : jeton révoqué, conservé jusqu'à sa fin de vie naturelle ;
- `refresh:grace:{jti}` : révoqué depuis moins de `GRACE_S` secondes → encore accepté
  (requêtes parallèles de l'app au moment d'une rotation).

Redis indisponible : la vérification laisse passer (« active ») et la révocation ne
fait pas échouer la réponse ; un warning est journalisé dans les deux cas (décision
PL 2026-06-19). Ni jeton ni `jti` n'apparaissent dans les journaux.
"""

from __future__ import annotations

import logging
from typing import Literal

from redis.asyncio import Redis
from redis.exceptions import RedisError

from app.core.config import settings

logger = logging.getLogger(__name__)

GRACE_S = 60
# Délais courts : une panne Redis ne doit pas bloquer la connexion des utilisatrices.
_SOCKET_TIMEOUT_S = 2.0

_client: Redis | None = None

RefreshState = Literal["active", "grace", "reused"]


def _get_client() -> Redis:
    global _client
    if _client is None:
        _client = Redis.from_url(
            settings.redis_url, socket_connect_timeout=_SOCKET_TIMEOUT_S, socket_timeout=_SOCKET_TIMEOUT_S
        )
    return _client


def set_client_for_tests(client: Redis | None) -> None:
    """Remplace le client (None → client paresseux sur `settings.redis_url`)."""
    global _client
    _client = client


def _revoked_key(jti: str) -> str:
    return f"revoked:jti:{jti}"


def _grace_key(jti: str) -> str:
    return f"refresh:grace:{jti}"


async def revoke_refresh(jti: str, ttl_s: int) -> None:
    """Révoque le refresh `jti` pour `ttl_s` secondes (reste de vie, 1 s minimum) + grâce de 60 s."""
    try:
        async with _get_client().pipeline(transaction=True) as pipe:
            pipe.set(_revoked_key(jti), 1, ex=max(1, int(ttl_s)))
            pipe.set(_grace_key(jti), 1, ex=GRACE_S)
            await pipe.execute()
    except (RedisError, OSError, TimeoutError) as exc:
        logger.warning("Redis indisponible : révocation du refresh token non enregistrée (%s)", type(exc).__name__)


async def refresh_state(jti: str) -> RefreshState:
    """`active` (jamais révoqué), `grace` (révoqué depuis ≤ 60 s) ou `reused` (révoqué avant)."""
    try:
        revoked, grace = await _get_client().mget(_revoked_key(jti), _grace_key(jti))
    except (RedisError, OSError, TimeoutError) as exc:
        logger.warning("Redis indisponible : révocation du refresh token non vérifiée (%s)", type(exc).__name__)
        return "active"
    if revoked is None:
        return "active"
    return "grace" if grace is not None else "reused"
