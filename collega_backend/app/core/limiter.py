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
from typing import Any

from fastapi import Request
from limits import parse
from slowapi import Limiter

from app.core.config import settings

logger = logging.getLogger(__name__)

_IPNetwork = ipaddress.IPv4Network | ipaddress.IPv6Network


@lru_cache(maxsize=8)
def _networks(cidrs: tuple[str, ...]) -> tuple[_IPNetwork, ...]:
    return tuple(ipaddress.ip_network(cidr, strict=False) for cidr in cidrs)


def _parse_ip(value: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address | None:
    try:
        return ipaddress.ip_address(value)
    except ValueError:
        return None


def _is_trusted(value: str) -> bool:
    """`value` est une IP appartenant à `settings.trusted_proxy_ips` (hôte non IP → faux)."""
    address = _parse_ip(value)
    if address is None:
        return False
    return any(address in network for network in _networks(tuple(settings.trusted_proxy_ips)))


def _rate_key(value: str) -> str:
    """Clé de limite d'une adresse : IPv6 regroupée par /64 (un abonné reçoit en général tout
    un /64 et changerait d'adresse à volonté) ; IPv4 et hôtes non IP inchangés."""
    address = _parse_ip(value)
    if isinstance(address, ipaddress.IPv6Address):
        return str(ipaddress.ip_network(f"{address}/64", strict=False))
    return value


def get_client_ip(request: Request) -> str:
    """Adresse de l'appelant (clé de limite), non falsifiable par le client.

    Topologie de prod : chemin public Cloudflare → conteneur cloudflared (réseau Docker
    net-edge, ex. 172.23.0.3) → Nginx Proxy Manager (réseau Docker) → API ; chemin LAN :
    client 192.168.x → NPM → API. NPM **ajoute** à `X-Forwarded-For` l'adresse qui s'est
    connectée à lui (`$remote_addr`) : le dernier élément est donc fiable, les précédents
    sont fournis par le client.

    Si la connexion vient d'un proxy de confiance (`settings.trusted_proxy_ips`, défaut
    172.16.0.0/12) et que le dernier élément de `X-Forwarded-For` est une IP valide :
    - si ce dernier saut est lui-même de confiance (requête entrée par cloudflared),
      `CF-Connecting-IP` (IP valide) est l'adresse du client ;
    - sinon (LAN, ou `CF-Connecting-IP` absent/invalide) → ce dernier saut. Un
      `CF-Connecting-IP` envoyé depuis le LAN est ignoré (falsifiable).
    Dernier saut absent ou non IP, ou connexion directe → l'adresse de la connexion.
    Jamais le 1er élément de `X-Forwarded-For`. IPv6 regroupée par /64.
    """
    host = request.client.host if request.client else None
    if not host:
        return "unknown"
    if _is_trusted(host):
        hops = [hop.strip() for hop in request.headers.get("X-Forwarded-For", "").split(",") if hop.strip()]
        last_hop = hops[-1] if hops else ""
        if _parse_ip(last_hop) is not None:
            if _is_trusted(last_hop):
                cf_ip = request.headers.get("CF-Connecting-IP", "").strip()
                if _parse_ip(cf_ip) is not None:
                    return _rate_key(cf_ip)
            return _rate_key(last_hop)
    return _rate_key(host)


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


# Redis injoignable : échec en ~2 s au plus au lieu de bloquer la requête (ignoré par memory://).
# Annotation `Any` : slowapi type ces options en `dict[str, str]`, redis attend des nombres.
_STORAGE_OPTIONS: dict[str, Any] = {"socket_timeout": 2, "socket_connect_timeout": 2}

limiter = Limiter(
    key_func=get_client_ip,
    storage_uri=settings.rate_limit_storage_uri or settings.redis_url,
    storage_options=_STORAGE_OPTIONS,
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
    Limiteur désactivé (`limiter.enabled`) → None.
    """
    if not limiter.enabled:
        return None
    try:
        if limiter.limiter.test(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip):
            return None
        reset_at = limiter.limiter.get_window_stats(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip).reset_time
    except Exception:  # noqa: BLE001 — limiteur en panne : jamais bloquant
        logger.warning("Limiteur indisponible : échecs d'authentification admin non vérifiés")
        return None
    return max(1, math.ceil(reset_at - time.time()))


def record_admin_auth_failure(ip: str) -> None:
    """Compte un échec d'authentification admin pour `ip` (stockage indisponible → warning ;
    limiteur désactivé → rien)."""
    if not limiter.enabled:
        return
    try:
        limiter.limiter.hit(_ADMIN_AUTH_FAILURES, _ADMIN_AUTH_SCOPE, ip)
    except Exception:  # noqa: BLE001 — limiteur en panne : jamais bloquant
        logger.warning("Limiteur indisponible : échec d'authentification admin non compté")
