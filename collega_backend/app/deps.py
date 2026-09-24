import asyncio
import secrets
import uuid

from arq.connections import ArqRedis
from fastapi import Depends, Header, Request
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.errors import AppError, forbidden, unauthorized
from app.core.limiter import admin_auth_retry_after, get_client_ip, record_admin_auth_failure
from app.core.security import JWTError, decode_token, token_version_ok

_http_basic = HTTPBasic()

__all__ = [
    "get_db",
    "get_arq",
    "get_arq_optional",
    "get_admin_user",
    "get_current_user",
    "get_current_user_short_session",
    "require_subscription",
]


# Une seule reconnexion paresseuse à la fois : sans verrou, des requêtes concurrentes
# ouvriraient chacune un pool, dont tous sauf un fuiraient.
_arq_reconnect_lock = asyncio.Lock()


async def get_arq_optional(request: Request) -> ArqRedis | None:
    """Pool ARQ de l'application (créé dans le lifespan), ou None si Redis reste injoignable.

    Si le pool manque (Redis injoignable au démarrage), une reconnexion est tentée.
    """
    state = request.app.state
    pool = getattr(state, "arq", None)
    if pool is not None:
        return pool
    connect = getattr(state, "arq_connect", None)
    if connect is None:
        return None
    async with _arq_reconnect_lock:
        pool = getattr(state, "arq", None)
        if pool is None:
            pool = await connect()
            state.arq = pool
    return pool


async def get_arq(request: Request) -> ArqRedis:
    """Pool ARQ de l'application ; 503 QUEUE_UNAVAILABLE si Redis reste injoignable."""
    pool = await get_arq_optional(request)
    if pool is None:
        raise AppError(503, "QUEUE_UNAVAILABLE", "File d'attente indisponible — réessayez")
    return pool


async def get_admin_user(
    request: Request,
    credentials: HTTPBasicCredentials = Depends(_http_basic),
) -> bool:
    """Protège toutes les routes /v1/admin/ par HTTP Basic Auth.

    Utilise secrets.compare_digest pour éviter les timing attacks. Seuls les **échecs**
    comptent pour la limite (10/min par IP, chantier 2 § 4) : la console enchaîne plusieurs
    requêtes par écran. Budget épuisé → 429 avant même de comparer les identifiants.
    """
    ip = get_client_ip(request)
    retry_after = admin_auth_retry_after(ip)
    if retry_after is not None:
        raise AppError(
            429,
            "RATE_LIMITED",
            "Trop de requêtes, réessayez plus tard",
            headers={"Retry-After": str(retry_after)},
        )
    correct_username = secrets.compare_digest(
        credentials.username.encode("utf-8"),
        settings.admin_username.encode("utf-8"),
    )
    correct_password = secrets.compare_digest(
        credentials.password.encode("utf-8"),
        settings.admin_password.encode("utf-8"),
    )
    if not (correct_username and correct_password):
        record_admin_auth_failure(ip)
        raise AppError(
            401,
            "INVALID_ADMIN_CREDENTIALS",
            "Identifiants administrateur invalides",
            headers={"WWW-Authenticate": "Basic"},
        )
    return True


async def get_current_user(
    request: Request,
    authorization: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """Extrait et valide le Bearer token, retourne l'utilisateur.

    Peuple `request.state.user_id` pour permettre aux rate limiters per-route
    (cf. `/v1/search`, Story 7.2 AC #3) de scoper par utilisateur plutôt que par IP.
    """
    from app.models.user import User

    if not authorization or not authorization.startswith("Bearer "):
        raise unauthorized("UNAUTHORIZED", "Token requis")
    token = authorization.removeprefix("Bearer ")
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise JWTError("Not an access token")
    except JWTError:
        raise unauthorized("TOKEN_EXPIRED", "Token invalide ou expiré") from None
    user_id = payload.get("sub")
    if not user_id:
        raise unauthorized("UNAUTHORIZED", "Token invalide")
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise unauthorized("UNAUTHORIZED", "Token invalide") from None
    user = await db.get(User, user_uuid)
    if not user:
        raise unauthorized("USER_NOT_FOUND", "Utilisateur introuvable")
    if not token_version_ok(payload, user.token_version):
        raise unauthorized("TOKEN_REVOKED", "Session révoquée — reconnectez-vous")
    request.state.user_id = str(user.id)
    return user


async def get_current_user_short_session(
    request: Request,
    authorization: str | None = Header(None),
):
    """Comme `get_current_user`, mais dans une session courte rendue aussitôt.

    Pour les réponses longues (flux SSE, jusqu'à 3 h) : une dépendance `get_db`
    n'est libérée qu'à la fin de la réponse, et garderait une connexion du pool
    pendant tout le flux (saturation à ~15 flux, incident de septembre 2026).
    """
    from app.core.database import async_session_factory

    async with async_session_factory() as db:
        return await get_current_user(request, authorization, db)


async def require_subscription(user=Depends(get_current_user)):
    """Guard FR42 : vérifie is_subscribed OR is_beta avant tout appel Claude."""
    if not (user.is_subscribed or user.is_beta):
        raise forbidden("SUBSCRIPTION_REQUIRED", "Abonnement actif requis")
    return user
