"""Utilitaires temps partagés entre router (quotas) et worker (cron monthly reset)."""

from __future__ import annotations

from datetime import datetime


def next_month_reset(now: datetime) -> datetime:
    """Retourne le 1er du mois prochain à minuit UTC.

    Exige un datetime timezone-aware en entrée : passer un naive datetime
    produirait un retour naive interprété ambigument (UTC vs local) côté
    Postgres `timestamp with time zone`.
    """
    assert now.tzinfo is not None, "next_month_reset requires a timezone-aware datetime"
    if now.month == 12:
        return now.replace(
            year=now.year + 1,
            month=1,
            day=1,
            hour=0,
            minute=0,
            second=0,
            microsecond=0,
        )
    return now.replace(
        month=now.month + 1,
        day=1,
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )
