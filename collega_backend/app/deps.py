import secrets
import uuid

from fastapi import Depends, Header, HTTPException, Request
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import JWTError, decode_token

_http_basic = HTTPBasic()
_http_basic_tester = HTTPBasic(auto_error=False)

__all__ = ["get_db", "get_admin_user", "get_tester_user", "get_current_user", "require_subscription"]


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


async def get_tester_user(
    credentials: HTTPBasicCredentials | None = Depends(_http_basic_tester),
) -> str:
    """Protège toutes les routes /v1/tester/ par HTTP Basic Auth.

    Retourne le tester_id (username) pour l'utiliser comme identifiant de feedback.
    Credentials distincts des credentials admin.
    Pas de WWW-Authenticate dans la 401 — sinon le navigateur affiche sa propre
    fenêtre native en boucle au lieu de laisser le formulaire HTML gérer l'erreur.
    """
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication required")
    correct_username = secrets.compare_digest(
        credentials.username.encode("utf-8"),
        settings.tester_username.encode("utf-8"),
    )
    correct_password = secrets.compare_digest(
        credentials.password.encode("utf-8"),
        settings.tester_password.encode("utf-8"),
    )
    if not (correct_username and correct_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return credentials.username


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
        )
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
        )
    user = await db.get(User, user_uuid)
    if not user:
        raise HTTPException(
            status_code=401,
            detail={"code": "USER_NOT_FOUND", "message": "Utilisateur introuvable"},
        )
    request.state.user_id = str(user.id)
    return user


async def require_subscription(user=Depends(get_current_user)):
    """Guard FR42 : vérifie is_subscribed OR is_beta avant tout appel Claude."""
    if not (user.is_subscribed or user.is_beta):
        raise HTTPException(
            status_code=403,
            detail={"code": "SUBSCRIPTION_REQUIRED", "message": "Abonnement actif requis"},
        )
    return user
