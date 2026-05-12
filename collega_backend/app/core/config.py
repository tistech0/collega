from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str
    redis_url: str
    secret_key: str
    claude_api_key: str = ""

    # Quotas anti-spam configurables sans redéploiement (FR45)
    reload_count_max: int = 2
    monthly_reloads_max: int = 3

    # Interface admin Phase 0 — HTTP Basic Auth
    admin_username: str = "admin"
    admin_password: str = "change-me"

    # Interface testeur Phase 0 — HTTP Basic Auth (credentials distincts de l'admin)
    tester_username: str = "tester"
    tester_password: str = "change-me"

    # Webhook RevenueCat — secret partagé (FR46)
    revenuecat_webhook_secret: str = ""

    # Stockage temporaire PDF (chemin configurable, nettoyé par cleanup_worker Story 1.3)
    pdf_storage_path: str = "/tmp/collega_pdfs"

    # APNs — token-based auth (fichier .p8 Apple Developer)
    apns_key_path: str = ""
    apns_key_id: str = ""
    apns_team_id: str = ""
    apns_bundle_id: str = "com.lesurmatthis.collega"
    apns_use_sandbox: bool = True

    @model_validator(mode="after")
    def _require_webhook_secret(self) -> "Settings":
        if not self.revenuecat_webhook_secret:
            raise ValueError("revenuecat_webhook_secret must be set (non-empty)")
        return self

    @model_validator(mode="after")
    def _require_distinct_tester_credentials(self) -> "Settings":
        if (
            self.tester_username == self.admin_username
            and self.tester_password == self.admin_password
        ):
            raise ValueError(
                "tester_username/tester_password must differ from admin credentials"
            )
        return self


settings = Settings()
