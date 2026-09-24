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
from collections.abc import Awaitable
from typing import Any, Literal, cast

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


# Révocation atomique et « premier arrivé » : seul le SET NX gagnant arme la grâce ; un
# jeton déjà révoqué n'est jamais modifié (pas de réarmement de la grâce).
# Retour : 1 = révoqué par cet appel, 2 = déjà révoqué et en grâce, 0 = déjà révoqué hors grâce.
_REVOKE_SCRIPT = """
if redis.call('SET', KEYS[1], '1', 'EX', ARGV[1], 'NX') then
  if ARGV[2] == '1' then
    redis.call('SET', KEYS[2], '1', 'EX', ARGV[3])
  end
  return 1
end
if redis.call('EXISTS', KEYS[2]) == 1 then
  return 2
end
return 0
"""

_REVOKE_RESULT: dict[int, RefreshState] = {1: "active", 2: "grace", 0: "reused"}


async def revoke_refresh(jti: str, ttl_s: int, *, grace: bool = True) -> RefreshState:
    """Révoque le refresh `jti` pour `ttl_s` secondes (reste de vie, 1 s minimum).

    `grace=True` (rotation) : arme aussi `refresh:grace:{jti}` 60 s pour les requêtes
    parallèles ; `grace=False` (logout) : révocation immédiate, sans grâce.
    Renvoie l'état du jeton AVANT l'appel : `active` si cet appel l'a révoqué (ou si
    Redis est indisponible), sinon `grace` / `reused` selon la révocation existante.
    """
    try:
        # redis-py type `eval` en « Awaitable | valeur » (clients sync/async) : on précise l'async.
        pending = _get_client().eval(
            _REVOKE_SCRIPT,
            2,
            _revoked_key(jti),
            _grace_key(jti),
            str(max(1, int(ttl_s))),
            "1" if grace else "0",
            str(GRACE_S),
        )
        result = await cast(Awaitable[Any], pending)
    except (RedisError, OSError, TimeoutError) as exc:
        logger.warning("Redis indisponible : révocation du refresh token non enregistrée (%s)", type(exc).__name__)
        return "active"
    return _REVOKE_RESULT.get(int(result), "reused")


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


async def close() -> None:
    """Ferme le client (arrêt de l'application)."""
    global _client
    client, _client = _client, None
    if client is not None:
        await client.aclose()
