from __future__ import annotations

import logging
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)


class NotificationService(ABC):
    @abstractmethod
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None: ...


class NullNotificationService(NotificationService):
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int
    ) -> None:
        logger.debug(
            "NullNotificationService: génération complète collège %s (APNs non configuré)",
            college_ref_id,
        )


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


_service_instance: NotificationService | None = None


def get_notification_service() -> NotificationService:
    global _service_instance
    if _service_instance is None:
        from app.core.config import settings

        if settings.apns_key_path and settings.apns_key_id and settings.apns_team_id:
            _service_instance = APNsNotificationService()
        else:
            _service_instance = NullNotificationService()
    return _service_instance
