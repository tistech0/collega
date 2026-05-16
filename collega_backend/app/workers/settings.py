from arq.cron import cron

from app.core.redis import redis_settings
from app.workers.cleanup_worker import cleanup_ocr_text
from app.workers.daily_reminder_worker import send_daily_reminders
from app.workers.generation_worker import generate_college_cards
from app.workers.ocr_worker import process_college_ocr

WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "functions": [process_college_ocr, generate_college_cards],
    "cron_jobs": [
        cron(cleanup_ocr_text, minute=0),
        cron(send_daily_reminders, minute=0),
    ],
    "max_jobs": 10,
    "job_timeout": 7200,
    "keep_result": 3600,
    "retry_jobs": True,
    "max_retries": 3,
}
