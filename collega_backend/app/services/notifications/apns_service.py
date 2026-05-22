from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from fastapi import Request

logger = logging.getLogger(__name__)


class NotificationService(ABC):
    @abstractmethod
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None: ...

    @abstractmethod
    async def send_daily_reminder(self, apns_token: str | None) -> None: ...

    async def close(self) -> None:
        """Cleanup hook appelé au shutdown lifespan/worker (Story 7.4)."""
        return None


class NullNotificationService(NotificationService):
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None:
        logger.debug(
            "NullNotificationService: génération complète collège %s (APNs non configuré)",
            college_ref_id,
        )

    async def send_daily_reminder(self, apns_token: str | None) -> None:
        logger.debug("NullNotificationService: rappel quotidien ignoré")


class APNsNotificationService(NotificationService):
    def __init__(self) -> None:
        from aioapns import APNs

        from app.core.config import settings

        self._apns = APNs(
            key=settings.apns_key_path,
            key_id=settings.apns_key_id,
            team_id=settings.apns_team_id,
            topic=settings.apns_bundle_id,
            use_sandbox=settings.apns_use_sandbox,
        )

    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None:
        if not apns_token:
            logger.info(
                "APNs token absent pour collège %s — notification ignorée", college_ref_id
            )
            return
        from aioapns import NotificationRequest, PushType

        request = NotificationRequest(
            device_token=apns_token,
            message={
                "aps": {
                    "alert": {
                        "title": "Fiches prêtes !",
                        "body": "Tes fiches sont disponibles dans AppMédecine",
                    },
                    "sound": "default",
                    "badge": 1,
                },
                "college_ref_id": college_ref_id,
            },
            push_type=PushType.ALERT,
        )
        result = await self._apns.send_notification(request)
        if result.is_successful:
            logger.info("Push APNs envoyé (collège %s)", college_ref_id)
        else:
            logger.warning(
                "Push APNs échoué pour collège %s : %s", college_ref_id, result.description
            )

    async def send_daily_reminder(self, apns_token: str | None) -> None:
        if not apns_token:
            return
        from aioapns import NotificationRequest, PushType

        request = NotificationRequest(
            device_token=apns_token,
            message={
                "aps": {
                    "alert": {
                        "title": "AppMédecine",
                        "body": "C'est l'heure de réviser !",
                    },
                    "sound": "default",
                },
            },
            push_type=PushType.ALERT,
        )
        result = await self._apns.send_notification(request)
        if not result.is_successful:
            logger.warning("Rappel push échoué : %s", result.description)

    async def close(self) -> None:
        """Ferme proprement la connexion HTTP/2 vers APNs.

        N'utilise QUE l'API publique `APNs.close()` si elle existe. Si l'objet
        n'expose pas `close()` publiquement (selon la version `aioapns`
        installée), on log explicitement et on laisse le GC nettoyer — c'est
        non bloquant et déterministe, plutôt que de dépendre d'attributs privés
        (`_connection_pool`) qui peuvent être renommés à chaque version mineure.
        """
        close_attr = getattr(self._apns, "close", None)
        if close_attr is None or not callable(close_attr):
            logger.info(
                "APNs client (%s) n'expose pas close() public — "
                "release HTTP/2 délégué au GC",
                type(self._apns).__name__,
            )
            return
        try:
            result = close_attr()
            if hasattr(result, "__await__"):
                await result  # type: ignore[func-returns-value]
        except Exception as exc:  # pragma: no cover - cleanup non bloquant
            logger.warning("APNs close() failed (non-bloquant) : %s", exc)


def create_notification_service() -> NotificationService:
    """Factory : construit un nouveau service selon la config (sans cache).

    Utilisée par le lifespan FastAPI (Story 7.4 AC #5) et le `on_startup`
    worker ARQ (AC #6). N'utilise pas le cache module-level — chaque process
    obtient sa propre instance.
    """
    from app.core.config import settings

    if settings.apns_key_path and settings.apns_key_id and settings.apns_team_id:
        return APNsNotificationService()
    return NullNotificationService()


_service_instance: NotificationService | None = None


def get_notification_service(
    request: "Request | None" = None,
    ctx: dict[str, Any] | None = None,
) -> NotificationService:
    """Récupère le singleton notification service.

    Priorité de résolution :
    1. `request.app.state.notification_service` (route FastAPI)
    2. `ctx["notification_service"]` (worker ARQ)
    3. `_service_instance` module-level (fallback rétrocompat tests + appels
       hors contexte lifespan/worker — instancié paresseusement à la 1re demande)
    """
    if request is not None:
        svc = getattr(request.app.state, "notification_service", None)
        if svc is not None:
            return svc
    if ctx is not None:
        svc = ctx.get("notification_service")
        if svc is not None:
            return svc
    global _service_instance
    if _service_instance is None:
        _service_instance = create_notification_service()
    return _service_instance
