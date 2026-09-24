"""Erreurs uniformes de l'API (chantier 5 § 4).

Toute erreur métier répond `{"detail": {"code": ..., "message": ..., **extra}}` : c'est le format
que l'app mobile lit (`detail.code`). Les 422 de validation, 429 du limiteur et 500 inattendues
passent au même format. Les `HTTPException` restantes (404/405 de routage Starlette, sécurité
FastAPI) gardent le gestionnaire par défaut.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded

logger = logging.getLogger(__name__)

_DEFAULT_RETRY_AFTER = 60


class AppError(Exception):
    """Erreur métier : statut HTTP + code stable lu par l'app + message en français."""

    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        extra: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(f"{status_code} {code}")
        self.status_code = status_code
        self.code = code
        self.message = message
        self.extra = extra or {}
        self.headers = headers

    @property
    def detail(self) -> dict[str, Any]:
        """Corps `detail` de la réponse (extra à plat, comme `reload_count` ou `missing`)."""
        return {"code": self.code, "message": self.message, **self.extra}


def not_found(code: str, message: str) -> AppError:
    return AppError(404, code, message)


def conflict(code: str, message: str, **extra: Any) -> AppError:
    return AppError(409, code, message, extra)


def unprocessable(code: str, message: str, **extra: Any) -> AppError:
    return AppError(422, code, message, extra)


def unauthorized(code: str, message: str) -> AppError:
    return AppError(401, code, message)


def forbidden(code: str, message: str) -> AppError:
    return AppError(403, code, message)


def _error_response(
    status_code: int, code: str, message: str, headers: dict[str, str] | None = None, **extra: Any
) -> JSONResponse:
    content = {"detail": {"code": code, "message": message, **extra}}
    return JSONResponse(status_code=status_code, content=jsonable_encoder(content), headers=headers)


async def _app_error_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, AppError)
    return JSONResponse(
        status_code=exc.status_code, content=jsonable_encoder({"detail": exc.detail}), headers=exc.headers
    )


async def _validation_error_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    # Seulement loc/msg/type : jamais la valeur reçue (`input`), qui peut être un mot de passe.
    errors = [{"loc": list(e.get("loc", ())), "msg": e.get("msg", ""), "type": e.get("type", "")} for e in exc.errors()]
    return _error_response(422, "VALIDATION_ERROR", "Requête invalide", errors=errors)


def _retry_after(exc: RateLimitExceeded) -> int:
    try:
        return int(exc.limit.limit.get_expiry())  # type: ignore[union-attr]
    except Exception:  # noqa: BLE001 — en-tête indicatif : défaut prudent
        return _DEFAULT_RETRY_AFTER


async def _rate_limit_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RateLimitExceeded)
    return _error_response(
        429,
        "RATE_LIMITED",
        "Trop de requêtes, réessayez plus tard",
        headers={"Retry-After": str(_retry_after(exc))},
    )


async def _internal_error_handler(request: Request, exc: Exception) -> JSONResponse:
    # Journalisée (trace comprise) ; la réponse ne contient aucun détail interne.
    logger.exception("Erreur interne sur %s %s", request.method, request.url.path, exc_info=exc)
    return _error_response(500, "INTERNAL_ERROR", "Erreur interne")


def install_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(AppError, _app_error_handler)
    app.add_exception_handler(RequestValidationError, _validation_error_handler)
    app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)
    app.add_exception_handler(Exception, _internal_error_handler)
