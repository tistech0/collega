from app.core.redis import redis_settings

# ARQ worker settings — configuration de la queue
WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "max_jobs": 10,
    "job_timeout": 7200,  # 2h max par job (NFR2)
    "keep_result": 3600,
    "retry_jobs": True,
}
