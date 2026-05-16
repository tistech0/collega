import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.core.database import async_session_factory
from app.models.user import User
from app.services.notifications.apns_service import get_notification_service

logger = logging.getLogger(__name__)


async def send_daily_reminders(ctx: dict) -> None:
    """Envoyé à :00 de chaque heure — notifie les users avec reminder_hour_utc == heure courante UTC."""
    current_hour = datetime.now(timezone.utc).hour
    async with async_session_factory() as db:
        result = await db.execute(
            select(User).where(
                User.reminder_hour_utc == current_hour,
                User.apns_token.is_not(None),
            )
        )
        users = result.scalars().all()
        logger.info("send_daily_reminders hour=%d → %d users", current_hour, len(users))
        svc = get_notification_service()
        for user in users:
            try:
                await svc.send_daily_reminder(user.apns_token)
            except Exception as e:  # noqa: BLE001
                logger.warning("Reminder push échoué user=%s : %s", user.id, e)
