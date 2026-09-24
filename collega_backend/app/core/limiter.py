"""Limiteur de débit (slowapi) et adresse client fiable (chantier 2 § 4).

Stockage indisponible (Redis coupé) : `swallow_errors=True` laisse passer la requête ;
slowapi journalise alors « Failed to rate limit. Swallowing error » (niveau ERROR, trace
comprise) sur le logger `slowapi`. Les échecs d'authentification admin, comptés à la main
ci-dessous, journalisent leur propre warning.
"""

from __future__ import annotations

import ipaddress
import logging
import math
import time
from functools import lru_cache

from fastapi import Request
from limits import parse
from slowapi import Limiter

from app.core.config import settings

logger = logging.getLogger(__name__)

_IPNetwork = ipaddress.IPv4Network | ipaddress.IPv6Network


@lru_cache(maxsize=8)
def _networks(cidrs: tuple[str, ...]) -> tuple[_IPNetwork, ...]:
    return tuple(ipaddress.ip_network(cidr, strict=False) for cidr in cidrs)


def _is_ip(value: str) -> bool:
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return False
    return True


def _from_trusted_proxy(host: str) -> bool:
    try:
        address = ipaddress.ip_address(host)
    except ValueError:  # hôte non IP (ex. « testclient ») : jamais un proxy de confiance
        return False
    return any(address in network for network in _networks(tuple(settings.trusted_proxy_ips)))


def get_client_ip(request: Request) -> str:
    """Adresse de l'appelant, non falsifiable par le client.

    Les en-têtes ne sont crus que si la connexion vient d'un proxy de confiance
    (`settings.trusted_proxy_ips`, défaut : réseau Docker de NPM) :
    1. `CF-Connecting-IP` (posé par Cloudflare) s'il contient une IP valide ;
    2. sinon le **dernier** élément de `X-Forwarded-For` (ajouté par NPM) ;
    3. sinon l'adresse de la connexion. Jamais le 1er élément de `X-Forwarded-For`,
       que le client choisit librement.
    """
    host = request.client.host if request.client else None
    if not host:
        return "unknown"
    if _from_trusted_proxy(host):
        cf_ip = request.headers.get("CF-Connecting-IP", "").strip()
        if cf_ip and _is_ip(cf_ip):
            return cf_ip
        hops = [hop.strip() for hop in request.headers.get("X-Forwarded-For", "").split(",") if hop.strip()]
        if hops:
            return hops[-1]
    return host


def user_id_key(request: Request) -> str:
    """Clé « par utilisatrice » : deux utilisatrices derrière la même IP (NAT de fac) ne se
    bloquent pas mutuellement.

    Lit `request.state.user_id`, posé par `get_current_user` après validation complète du
    jeton (signature, `tv`, utilisatrice existante). slowapi évalue la limite dans l'enveloppe
    de l'endpoint, donc après la résolution de *toutes* les dépendances FastAPI : l'ordre de
    résolution n'a pas d'incidence. Repli sur l'IP (préfixe `ip:`) si l'état est absent.
    """
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return f"user:{user_id}"
    return f"ip:{get_client_ip(request)}"


limiter = Limiter(
    key_func=get_client_ip,
    storage_uri=settings.rate_limit_storage_uri or settings.redis_url,
    swallow_errors=True,
)


# ── Échecs d'authentification admin : 10/min par IP ─────────────────────────────
# Seuls les échecs comptent (la console enchaîne plusieurs requêtes par écran) : compteur
# tenu à la main sur le stockage du limiteur (même Redis, remis à zéro par `limiter.reset()`).

_ADMIN_AUTH_FAILURES = parse("10/minute")
_ADMIN_AUTH_SCOPE = "admin-auth"


def admin_auth_retry_after(ip: str) -> int | None:
    """Secondes avant la fin de la fenêtre si le budget d'échecs de `ip` est épuisé, sinon None.

    Stockage indisponible → warning et None (on laisse passer, comme `swallow_errors`).
    """
    try:
        if limiter.limiter.test(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip):
            return None
        reset_at = limiter.limiter.get_window_stats(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip).reset_time
    except Exception:  # noqa: BLE001 — limiteur en panne : jamais bloquant
        logger.warning("Limiteur indisponible : échecs d'authentification admin non vérifiés")
        return None
    return max(1, math.ceil(reset_at - time.time()))


def record_admin_auth_failure(ip: str) -> None:
    """Compte un échec d'authentification admin pour `ip` (stockage indisponible → warning)."""
    try:
        limiter.limiter.hit(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip)
    except Exception:  # noqa: BLE001 — limiteur en panne : jamais bloquant
        logger.warning("Limiteur indisponible : échec d'authentification admin non compté")
