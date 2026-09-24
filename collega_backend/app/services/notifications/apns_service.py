from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from fastapi import Request

logger = logging.getLogger(__name__)


def _plural(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def completion_message(summary: dict | None) -> tuple[str, str]:
    """(titre, corps) de la notification de fin d'import. `summary` = résumé de la
    bascule d'un réimport (None pour un premier import)."""
    if not summary:
        return "Fiches prêtes", "Tes fiches t’attendent dans Collega."
    if not (summary.get("changed") or summary.get("added") or summary.get("removed")):
        if summary.get("quota_refunded"):
            return "Aucun changement", "Aucun changement dans ce PDF : ton réimport n’a pas été décompté."
        return "Aucun changement", "Aucun changement dans ce PDF."
    parts = [
        _plural(summary["changed"], "item mis à jour", "items mis à jour") if summary.get("changed") else None,
        _plural(summary["added"], "nouveau", "nouveaux") if summary.get("added") else None,
        _plural(summary["removed"], "supprimé", "supprimés") if summary.get("removed") else None,
        _plural(summary["unchanged"], "inchangé", "inchangés") if summary.get("unchanged") else None,
    ]
    return "Fiches mises à jour", ", ".join(p for p in parts if p) + "."


def failure_message(reimport: bool, college_name: str) -> tuple[str, str]:
    if reimport:
        return (
            "Réimport interrompu",
            f"Le réimport de {college_name} n’a pas abouti. Tes fiches actuelles sont intactes.",
        )
    return "Import interrompu", f"L’import de {college_name} n’a pas abouti. Relance-le depuis l’app."


def college_label(college_ref_id: int) -> str:
    # Le catalogue des noms de collèges vit côté app.
    return f"ton collège n°{college_ref_id}"


class NotificationService(ABC):
    @abstractmethod
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int, summary: dict | None = None
    ) -> None: ...

    @abstractmethod
    async def send_import_failed(self, apns_token: str | None, college_ref_id: int, reimport: bool) -> None: ...

    @abstractmethod
    async def send_daily_reminder(self, apns_token: str | None) -> None: ...

    async def close(self) -> None:
        """Cleanup hook appelé au shutdown lifespan/worker (Story 7.4)."""
        return None


class NullNotificationService(NotificationService):
    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int, summary: dict | None = None
    ) -> None:
        logger.debug(
            "NullNotificationService: génération complète collège %s (APNs non configuré)",
            college_ref_id,
        )

    async def send_import_failed(self, apns_token: str | None, college_ref_id: int, reimport: bool) -> None:
        logger.debug("NullNotificationService: échec d'import collège %s (APNs non configuré)", college_ref_id)

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

    async def _send_alert(
        self, apns_token: str | None, title: str, body: str, *, extra: dict | None = None, badge: bool = False
    ) -> None:
        if not apns_token:
            logger.info("APNs token absent — notification « %s » ignorée", title)
            return
        from aioapns import NotificationRequest, PushType

        aps: dict[str, Any] = {"alert": {"title": title, "body": body}, "sound": "default"}
        if badge:
            aps["badge"] = 1
        request = NotificationRequest(
            device_token=apns_token,
            message={"aps": aps, **(extra or {})},
            push_type=PushType.ALERT,
        )
        result = await self._apns.send_notification(request)
        if result.is_successful:
            logger.info("Push APNs envoyé : %s", title)
        else:
            logger.warning("Push APNs échoué (%s) : %s", title, result.description)

    async def send_generation_complete(
        self, apns_token: str | None, college_ref_id: int, summary: dict | None = None
    ) -> None:
        title, body = completion_message(summary)
        await self._send_alert(apns_token, title, body, extra={"college_ref_id": college_ref_id}, badge=True)

    async def send_import_failed(self, apns_token: str | None, college_ref_id: int, reimport: bool) -> None:
        title, body = failure_message(reimport, college_label(college_ref_id))
        await self._send_alert(apns_token, title, body, extra={"college_ref_id": college_ref_id})

    async def send_daily_reminder(self, apns_token: str | None) -> None:
        await self._send_alert(apns_token, "Collega", "Ta session du jour t’attend.")

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
                "APNs client (%s) n'expose pas close() public — release HTTP/2 délégué au GC",
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
    request: Request | None = None,
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
