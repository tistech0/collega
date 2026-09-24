import logging

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)

_KNOWN_ENVIRONMENTS = frozenset({"development", "production"})

# Listes fermées de placeholders connus (issus de `.env.example`). On préfère
# une égalité explicite à une recherche par substring, qui rejetait à tort des
# secrets légitimes contenant `change-me*` ou `in-production`.
_PLACEHOLDER_SECRET_KEYS = frozenset(
    {
        "change-me",
        "change-me-in-production",
        "change-me-in-production-use-at-least-32-chars",
    }
)
_PLACEHOLDER_PASSWORDS = frozenset({"change-me", "change-me-in-production"})
_PLACEHOLDER_WEBHOOK_SECRETS = frozenset({"change-me", "change-me-in-production"})

# Longueur minimale plausible pour une vraie clé Anthropic — le préfixe nu
# `sk-ant-` (7 chars) ou les clés tronquées doivent être rejetées en prod.
_CLAUDE_API_KEY_MIN_LEN = 20


class Settings(BaseSettings):
    # hide_input_in_errors : une config refusée ne recopie jamais les valeurs (secrets) dans l'erreur.
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore", hide_input_in_errors=True
    )

    environment: str = "development"  # "development" | "production"

    database_url: str
    redis_url: str
    # Tests : "memory://" (compteurs par processus, plus de Redis local requis).
    rate_limit_storage_uri: str = ""
    secret_key: str
    claude_api_key: str = ""

    # Quotas anti-spam configurables sans redéploiement (FR45)
    reload_count_max: int = 2
    monthly_reloads_max: int = 3

    # Taux de conversion USD→EUR pour le calcul de coût des tokens Claude
    # (Story 7.8). Valeur par défaut ici (PAS dans le .env prod NAS, cf. mémoire
    # projet) ; surchargeable via la variable d'env USD_EUR_RATE si besoin.
    usd_eur_rate: float = 0.92

    # Interface admin Phase 0 — HTTP Basic Auth
    admin_username: str = "admin"
    admin_password: str = "change-me"

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
    def _validate_production_secrets(self) -> "Settings":
        # Strip + lower : `ENVIRONMENT=" production "` (espaces dans .env) ne
        # doit pas être traité silencieusement comme `development`.
        env_normalized = self.environment.strip().lower()
        is_prod = env_normalized == "production"

        # Toute valeur autre que `development`/`production` est probablement
        # une typo (`prod`, `prd`, `PROD`) — fail-open silencieux interdit.
        if env_normalized not in _KNOWN_ENVIRONMENTS:
            logger.warning(
                "Unknown ENVIRONMENT=%r — treated as development. Expected one of: %s.",
                self.environment,
                ", ".join(sorted(_KNOWN_ENVIRONMENTS)),
            )

        issues: list[str] = []

        # Toutes les valeurs sont strippées avant comparaison — un trailing
        # whitespace dans `.env` ne doit pas masquer un placeholder.
        secret_key = self.secret_key.strip()
        claude_api_key = self.claude_api_key.strip()
        admin_password = self.admin_password.strip()
        webhook_secret = self.revenuecat_webhook_secret.strip()

        # SECRET_KEY : taille mini ET pas de placeholder (deux contrôles
        # indépendants, pour signaler les deux violations simultanément).
        if len(secret_key) < 32:
            issues.append("SECRET_KEY (must be ≥ 32 chars)")
        if secret_key in _PLACEHOLDER_SECRET_KEYS:
            issues.append("SECRET_KEY (default placeholder value)")

        # CLAUDE_API_KEY : non vide + format Anthropic + longueur plausible.
        if not claude_api_key:
            issues.append("CLAUDE_API_KEY (empty)")
        elif not claude_api_key.startswith("sk-ant-"):
            issues.append("CLAUDE_API_KEY (invalid format — expected sk-ant-…)")
        elif len(claude_api_key) < _CLAUDE_API_KEY_MIN_LEN:
            issues.append(f"CLAUDE_API_KEY (too short — must be ≥ {_CLAUDE_API_KEY_MIN_LEN} chars)")

        # ADMIN_PASSWORD : non vide + pas de placeholder.
        if not admin_password or admin_password in _PLACEHOLDER_PASSWORDS:
            issues.append("ADMIN_PASSWORD (default placeholder value)")

        # REVENUECAT_WEBHOOK_SECRET : pas de placeholder (le non-vide est déjà
        # vérifié par _require_webhook_secret au-dessus).
        if webhook_secret in _PLACEHOLDER_WEBHOOK_SECRETS:
            issues.append("REVENUECAT_WEBHOOK_SECRET (default placeholder value)")

        if not issues:
            return self

        msg = f"Insecure config values: {', '.join(issues)}"
        if is_prod:
            raise ValueError(f"Production secrets invalid — {msg}. Refuse to start.")
        logger.warning("DEV mode: %s — DO NOT deploy as-is.", msg)
        return self


settings = Settings()
