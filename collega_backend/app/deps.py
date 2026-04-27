import secrets

from fastapi import Depends, HTTPException
from fastapi.security import HTTPBasic, HTTPBasicCredentials

from app.core.config import settings
from app.core.database import get_db

_http_basic = HTTPBasic()

__all__ = ["get_db", "get_admin_user"]


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
