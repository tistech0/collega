"""Schemas Pydantic pour le webhook RevenueCat (FR46)."""

from __future__ import annotations

from pydantic import BaseModel, Field


class RevenueCatEventData(BaseModel):
    type: str
    app_user_id: str
    product_id: str | None = None
    price: float | None = None
    currency: str | None = None
    # Horodatage de l'événement (ms epoch) : sert à ignorer un événement arrivé en retard.
    # Bornes : dates représentables par `datetime` (sinon 500 à la conversion).
    event_timestamp_ms: int | None = Field(default=None, ge=0, le=253_402_300_799_999)


class RevenueCatWebhookPayload(BaseModel):
    event: RevenueCatEventData
    api_version: str | None = None
