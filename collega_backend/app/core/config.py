from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    redis_url: str
    secret_key: str
    claude_api_key: str

    # Quotas anti-spam configurables sans redéploiement (FR45)
    reload_count_max: int = 2
    monthly_reloads_max: int = 3

    # Interface admin Phase 0
    admin_username: str = "admin"
    admin_password: str = "change-me"


settings = Settings()
