import logging
import ssl
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.v1.admin import router as admin_router
from app.api.v1.auth import router as auth_router
from app.api.v1.billing import router as billing_router
from app.api.v1.colleges import router as colleges_router
from app.api.v1.drill import router as drill_router
from app.api.v1.flash_cards import router as flash_cards_router
from app.api.v1.health import router as health_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.search import router as search_router
from app.api.v1.tester import router as tester_router
from app.core.config import settings
from app.core.database import engine
from app.core.limiter import limiter
from app.core.logging import configure_logging

configure_logging()
logger = logging.getLogger(__name__)


def openapi_url_for(environment: str) -> str | None:
    # Le schéma liste toutes les routes, admin comprises : caché en production.
    return None if environment == "production" else "/openapi.json"


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Story 7.4 AC #5 — init APNs singleton au démarrage.
    # Import local pour permettre aux tests de monkeypatch `create_notification_service`.
    from app.services.notifications import apns_service

    try:
        app.state.notification_service = apns_service.create_notification_service()
        # Sync du fallback module-level pour que tout appel
        # `get_notification_service()` SANS request/ctx (BackgroundTasks,
        # scripts, tests qui n'entrent pas dans le lifespan context) renvoie
        # la MÊME instance que `app.state` — évite la création d'une 2e
        # instance APNs parallèle qui défait l'objectif singleton.
        apns_service._service_instance = app.state.notification_service

        logger.info(
            "Notification service initialized (type=%s, sandbox=%s)",
            type(app.state.notification_service).__name__,
            settings.apns_use_sandbox,
        )
    except (
        FileNotFoundError,
        OSError,
        ssl.SSLError,
        ValueError,
    ) as exc:
        # Narrow exceptions : seuls les échecs d'init APNs attendus (config
        # manquante, .p8 illisible, TLS broken). Les bugs de code
        # (`ImportError`, `AssertionError`, `AttributeError`) doivent
        # remonter pour ne pas désactiver silencieusement le push en prod.
        logger.warning(
            "Failed to init APNs service — falling back to NullNotificationService: %s",
            exc,
        )
        app.state.notification_service = apns_service.NullNotificationService()
        apns_service._service_instance = app.state.notification_service

    try:
        yield
    finally:
        # Cleanup APNs avant dispose DB (Story 7.4 AC #5).
        svc = getattr(app.state, "notification_service", None)
        if svc is not None:
            try:
                await svc.close()
            except Exception as exc:  # pragma: no cover - cleanup non bloquant
                logger.warning("APNs close() during shutdown failed: %s", exc)
        # Reset du module-level singleton pour que les tests suivants ne
        # voient pas l'instance fermée.
        apns_service._service_instance = None
        await engine.dispose()


app = FastAPI(
    title="Collega API",
    version="0.3.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=openapi_url_for(settings.environment),
    lifespan=lifespan,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.include_router(health_router)
app.include_router(auth_router, prefix="/v1/auth")
app.include_router(colleges_router, prefix="/v1")
app.include_router(flash_cards_router, prefix="/v1")
app.include_router(drill_router, prefix="/v1")
app.include_router(notifications_router, prefix="/v1")
app.include_router(search_router, prefix="/v1")
app.include_router(admin_router, prefix="/v1/admin")
app.include_router(billing_router, prefix="/v1/webhooks")
app.include_router(tester_router, prefix="/v1/tester")
# StaticFiles doit être monté EN DERNIER pour ne pas masquer les routes API
app.mount("/admin", StaticFiles(directory=str(Path(__file__).parent / "static" / "admin"), html=True), name="admin-static")
app.mount("/tester", StaticFiles(directory=str(Path(__file__).parent / "static"), html=True), name="tester-static")
