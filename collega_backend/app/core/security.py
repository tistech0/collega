import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from jwt import PyJWTError as JWTError
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 30


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def _create_token(user_id: str, token_type: str, lifetime: timedelta, token_version: int) -> str:
    """Jeton HS256 : `jti` unique (révocation, chantier 2) et `tv` = `users.token_version` à l'émission."""
    from app.core.config import settings

    payload: dict[str, Any] = {
        "sub": user_id,
        "type": token_type,
        "exp": datetime.now(UTC) + lifetime,
        "jti": uuid.uuid4().hex,
        "tv": token_version,
    }
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def create_access_token(user_id: str, token_version: int = 0) -> str:
    return _create_token(user_id, "access", timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES), token_version)


def create_refresh_token(user_id: str, token_version: int = 0) -> str:
    return _create_token(user_id, "refresh", timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS), token_version)


def decode_token(token: str) -> dict[str, Any]:
    """Lève JWTError si le jeton est mal formé, mal signé ou expiré."""
    from app.core.config import settings

    return jwt.decode(token, settings.secret_key, algorithms=["HS256"])


def token_version_ok(payload: dict[str, Any], current_version: int) -> bool:
    """Le jeton est-il émis à la version courante (ou après) ?

    Transition : un jeton sans `tv` (émis avant le chantier 2) reste valable tant
    que la version de l'utilisatrice vaut 0 (pas de déconnexion au déploiement).
    """
    tv = payload.get("tv")
    if tv is None:
        return current_version == 0
    return isinstance(tv, int) and tv >= current_version


__all__ = [
    "hash_password",
    "verify_password",
    "create_access_token",
    "create_refresh_token",
    "decode_token",
    "token_version_ok",
    "JWTError",
]
