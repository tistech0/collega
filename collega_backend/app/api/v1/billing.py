"""Webhook RevenueCat — mise à jour statut abonnement (FR46)."""

from __future__ import annotations

import logging
import secrets
import uuid

from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.errors import not_found, unauthorized, unprocessable
from app.schemas.billing import RevenueCatWebhookPayload

logger = logging.getLogger(__name__)
router = APIRouter(tags=["billing"])

_ACTIVE_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}
_INACTIVE_EVENTS = {"CANCELLATION", "EXPIRATION"}


@router.post("/revenuecat", status_code=200)
async def revenuecat_webhook(
    payload: RevenueCatWebhookPayload,
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Traite les events RevenueCat et met à jour user.is_subscribed."""
    auth_token = authorization.removeprefix("Bearer ") if authorization else None
    if not auth_token or not secrets.compare_digest(auth_token.encode(), settings.revenuecat_webhook_secret.encode()):
        raise unauthorized("INVALID_SIGNATURE", "Invalid or missing Authorization")

    event_type = payload.event.type

    if event_type not in _ACTIVE_EVENTS and event_type not in _INACTIVE_EVENTS:
        logger.info("RevenueCat event ignored: %s", event_type)
        return {"data": {"status": "ignored"}}

    try:
        user_id = uuid.UUID(payload.event.app_user_id)
    except ValueError:
        raise unprocessable("INVALID_USER_ID", "app_user_id is not a valid UUID") from None

    from app.models.user import User

    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")

    user.is_subscribed = event_type in _ACTIVE_EVENTS
    await db.commit()
    logger.info("User %s is_subscribed=%s via event %s", user_id, user.is_subscribed, event_type)

    return {"data": {"status": "updated", "is_subscribed": user.is_subscribed}}
