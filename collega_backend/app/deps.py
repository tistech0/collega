import asyncio
import secrets
import uuid

from arq.connections import ArqRedis
from fastapi import Depends, Header, HTTPException, Request
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import JWTError, decode_token

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
        raise HTTPException(
            status_code=503,
            detail={"code": "QUEUE_UNAVAILABLE", "message": "File d'attente indisponible — réessayez"},
        )
    return pool


async def get_admin_user(
    credentials: HTTPBasicCredentials = Depends(_http_basic),
) -> bool:
    """Protège toutes les routes /v1/admin/ par HTTP Basic Auth.

    Utilise secrets.compare_digest pour éviter les timing attacks.
    """
    correct_username = secrets.compare_digest(
        credentials.username.encode("utf-8"),
        settings.admin_username.encode("utf-8"),
    )
    correct_password = secrets.compare_digest(
        credentials.password.encode("utf-8"),
        settings.admin_password.encode("utf-8"),
    )
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
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
        raise HTTPException(
            status_code=401,
            detail={"code": "UNAUTHORIZED", "message": "Token requis"},
        )
    token = authorization.removeprefix("Bearer ")
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise JWTError("Not an access token")
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail={"code": "TOKEN_EXPIRED", "message": "Token invalide ou expiré"},
        ) from None
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail={"code": "UNAUTHORIZED", "message": "Token invalide"},
        )
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=401,
            detail={"code": "UNAUTHORIZED", "message": "Token invalide"},
        ) from None
    user = await db.get(User, user_uuid)
    if not user:
        raise HTTPException(
            status_code=401,
            detail={"code": "USER_NOT_FOUND", "message": "Utilisateur introuvable"},
        )
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
        raise HTTPException(
            status_code=403,
            detail={"code": "SUBSCRIPTION_REQUIRED", "message": "Abonnement actif requis"},
        )
    return user
