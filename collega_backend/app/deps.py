import secrets

from fastapi import Depends, HTTPException
from fastapi.security import HTTPBasic, HTTPBasicCredentials

from app.core.config import settings
from app.core.database import get_db

_http_basic = HTTPBasic()
_http_basic_tester = HTTPBasic(auto_error=False)

__all__ = ["get_db", "get_admin_user", "get_tester_user"]


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
