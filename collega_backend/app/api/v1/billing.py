"""Webhook RevenueCat — mise à jour statut abonnement (FR46).

Chantier 2 § 5 : le secret partagé est vérifié AVANT toute lecture du corps (aucune
validation, donc aucune 422, pour un appel non authentifié), et les événements sont
ordonnés par leur horodatage (`users.subscription_event_at`).
"""

from __future__ import annotations

import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Header, Request
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.errors import not_found, unauthorized, unprocessable
from app.models.user import User
from app.schemas.billing import RevenueCatWebhookPayload

logger = logging.getLogger(__name__)
router = APIRouter(tags=["billing"])

_ACTIVE_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}
_INACTIVE_EVENTS = {"CANCELLATION", "EXPIRATION"}


def _event_time(timestamp_ms: int) -> datetime:
    # Arithmétique entière : pas d'arrondi flottant sur les millisecondes.
    return datetime.fromtimestamp(timestamp_ms // 1000, UTC) + timedelta(milliseconds=timestamp_ms % 1000)


async def _parse_payload(request: Request) -> RevenueCatWebhookPayload:
    """Valide le corps brut ; une erreur passe par le gestionnaire commun (422 VALIDATION_ERROR)."""
    try:
        return RevenueCatWebhookPayload.model_validate_json(await request.body())
    except ValidationError as exc:
        # Même forme qu'une validation FastAPI du corps : `loc` préfixé par "body".
        errors = [{**err, "loc": ("body", *err.get("loc", ()))} for err in exc.errors()]
        raise RequestValidationError(errors) from None


@router.post("/revenuecat", status_code=200)
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Traite les events RevenueCat et met à jour user.is_subscribed."""
    auth_token = authorization.removeprefix("Bearer ") if authorization else None
    if not auth_token or not secrets.compare_digest(auth_token.encode(), settings.revenuecat_webhook_secret.encode()):
        raise unauthorized("INVALID_SIGNATURE", "Invalid or missing Authorization")

    payload = await _parse_payload(request)
    event_type = payload.event.type

    if event_type not in _ACTIVE_EVENTS and event_type not in _INACTIVE_EVENTS:
        logger.info("RevenueCat event ignored: %s", event_type)
        return {"data": {"status": "ignored"}}

    try:
        user_id = uuid.UUID(payload.event.app_user_id)
    except ValueError:
        raise unprocessable("INVALID_USER_ID", "app_user_id is not a valid UUID") from None

    # Verrou de ligne : deux webhooks concurrents pour la même utilisatrice se sérialisent,
    # la comparaison d'horodatage voit donc toujours la dernière valeur appliquée.
    user = await db.get(User, user_id, with_for_update=True)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")

    event_at = _event_time(payload.event.event_timestamp_ms) if payload.event.event_timestamp_ms is not None else None
    if event_at is not None and user.subscription_event_at is not None and event_at < user.subscription_event_at:
        await db.rollback()  # libère le verrou
        logger.info("RevenueCat event stale for user %s: %s", user_id, event_type)
        return {"data": {"status": "stale"}}

    user.is_subscribed = event_type in _ACTIVE_EVENTS
    if event_at is not None:
        user.subscription_event_at = event_at
    await db.commit()
    logger.info("User %s is_subscribed=%s via event %s", user_id, user.is_subscribed, event_type)

    return {"data": {"status": "updated", "is_subscribed": user.is_subscribed}}
