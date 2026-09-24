import logging
import ssl

from arq.cron import cron

from app.core.logging import configure_logging
from app.core.redis import redis_settings
from app.workers.cleanup_worker import cleanup_stale_uploads, reset_monthly_reloads
from app.workers.daily_reminder_worker import send_daily_reminders
from app.workers.generation_worker import generate_college_cards
from app.workers.maintenance_worker import fail_stale_jobs, purge_content
from app.workers.ocr_worker import process_college_ocr

configure_logging()
# arq pose son propre handler sur le logger « arq » : sans ceci, chaque ligne
# d'arq sortirait deux fois (son handler + celui de la racine).
logging.getLogger("arq").propagate = False
logger = logging.getLogger(__name__)


async def _worker_startup(ctx: dict) -> None:
    """Initialise le singleton NotificationService côté worker ARQ (Story 7.4 AC #6).

    Le `lifespan` FastAPI ne couvre que le process web — le worker ARQ tourne
    dans un process séparé et doit donc instancier son propre service. Le
    service est stocké dans `ctx["notification_service"]` ; les fonctions
    worker peuvent y accéder via `ctx` (préférer ce chemin) ou via
    `get_notification_service(ctx=ctx)` (rétro-compatible).
    """
    from app.services.notifications import apns_service

    try:
        ctx["notification_service"] = apns_service.create_notification_service()
        # Sync module-level pour les workers fonctions qui appelleraient
        # `get_notification_service()` sans propager `ctx` (rare mais possible).
        apns_service._service_instance = ctx["notification_service"]
        logger.info(
            "Worker: notification service initialized (type=%s)",
            type(ctx["notification_service"]).__name__,
        )
    except (
        FileNotFoundError,
        OSError,
        ssl.SSLError,
        ValueError,
    ) as exc:
        # Narrow exceptions : seuls les échecs attendus d'init APNs sont
        # interceptés (config absente, .p8 illisible, TLS broken). Les bugs
        # de code (ImportError, AssertionError, AttributeError) remontent
        # pour ne pas désactiver silencieusement le push.
        logger.warning(
            "Worker: failed to init APNs — falling back to NullNotificationService: %s",
            exc,
        )
        ctx["notification_service"] = apns_service.NullNotificationService()
        apns_service._service_instance = ctx["notification_service"]


async def _worker_shutdown(ctx: dict) -> None:
    """Ferme proprement la connexion APNs au shutdown du worker (Story 7.4 AC #6)."""
    from app.services.notifications import apns_service

    svc = ctx.get("notification_service")
    if svc is None:
        return
    try:
        await svc.close()
    except Exception as exc:  # pragma: no cover - cleanup non bloquant
        logger.warning("Worker: APNs close() failed: %s", exc)
    finally:
        # Reset du singleton module-level — sinon un test ultérieur qui
        # importe le module verrait une instance fermée.
        apns_service._service_instance = None


WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "functions": [process_college_ocr, generate_college_cards],
    "cron_jobs": [
        cron(fail_stale_jobs, minute={0, 10, 20, 30, 40, 50}),
        cron(purge_content, hour=4, minute=15),
        cron(send_daily_reminders, minute=0),
        cron(reset_monthly_reloads, hour=0, minute=5),
        cron(cleanup_stale_uploads, minute=30),
    ],
    "on_startup": _worker_startup,
    "on_shutdown": _worker_shutdown,
    "max_jobs": 10,
    "job_timeout": 7200,
    "keep_result": 3600,
    "retry_jobs": True,
    # arq lit `max_tries` (défaut 5) ; l'ancienne clé `max_retries` était ignorée.
    # Chaque relance d'une génération repaie Claude : 3 tentatives au plus.
    "max_tries": 3,
    # Story 7.7 — sans ce flag, Job.abort() est ignoré par le worker et le job
    # continue malgré la demande d'annulation de l'endpoint Stop.
    "allow_abort_jobs": True,
    # Clé lue par `arq --check` (healthcheck Docker du worker) ; défaut 3600 s.
    "health_check_interval": 60,
}
