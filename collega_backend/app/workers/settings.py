from app.core.redis import redis_settings
from app.workers.ocr_worker import process_college_ocr

# ARQ worker settings — configuration de la queue
WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "functions": [process_college_ocr],
    "max_jobs": 10,
    "job_timeout": 7200,  # 2h max par job (NFR2)
    "keep_result": 3600,
    "retry_jobs": True,
    "max_retries": 3,  # bug Story 1.1 — jobs ne doivent pas boucler indéfiniment
}
