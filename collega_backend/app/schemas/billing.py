"""Schemas Pydantic pour le webhook RevenueCat (FR46)."""

from __future__ import annotations

from pydantic import BaseModel


class RevenueCatEventData(BaseModel):
    type: str
    app_user_id: str
    product_id: str | None = None
    price: float | None = None
    currency: str | None = None


class RevenueCatWebhookPayload(BaseModel):
    event: RevenueCatEventData
    api_version: str | None = None
