import ipaddress
import logging
from typing import Annotated, Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

logger = logging.getLogger(__name__)

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

    # Obligatoire (chantier 2 § 6) : absente ou hors liste → démarrage refusé. Une typo
    # (`prod`) n'est plus traitée silencieusement comme `development`.
    environment: Literal["development", "production", "test"]

    database_url: str
    redis_url: str
    # Tests : "memory://" (compteurs par processus, plus de Redis local requis).
    rate_limit_storage_uri: str = ""
    # Proxys dont on croit les en-têtes CF-Connecting-IP / X-Forwarded-For (chantier 2 § 4).
    # Défaut : réseau Docker de Nginx Proxy Manager. Variable TRUSTED_PROXY_IPS : réseaux
    # (CIDR) ou adresses séparés par des virgules ; vide = aucun proxy de confiance.
    trusted_proxy_ips: Annotated[list[str], NoDecode] = ["172.16.0.0/12"]
    secret_key: str
    claude_api_key: str = ""

    # Quotas anti-spam configurables sans redéploiement (FR45)
    reload_count_max: int = 2
    monthly_reloads_max: int = 3

    # Items générés en parallèle par import (chantier 4) : appels Claude simultanés.
    # 2 par défaut (revue finale) : le parallélisme n'a jamais été mesuré contre les
    # limites de débit réelles du compte, et plusieurs imports peuvent tourner à la fois
    # (worker max_jobs 10). À relever par la variable GENERATION_CONCURRENCY si besoin.
    generation_concurrency: int = Field(2, ge=1)

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

    @field_validator("trusted_proxy_ips", mode="before")
    @classmethod
    def _split_trusted_proxy_ips(cls, value: object) -> object:
        if isinstance(value, str):
            return [part.strip() for part in value.split(",") if part.strip()]
        return value

    @field_validator("trusted_proxy_ips")
    @classmethod
    def _check_trusted_proxy_ips(cls, value: list[str]) -> list[str]:
        # Un réseau mal saisi refuse le démarrage (sinon l'IP client retomberait
        # silencieusement sur celle du proxy : toutes les utilisatrices partageraient un compteur).
        for network in value:
            try:
                ipaddress.ip_network(network, strict=False)
            except ValueError:
                raise ValueError(f"TRUSTED_PROXY_IPS: réseau invalide {network!r}") from None
        return value

    @model_validator(mode="after")
    def _require_webhook_secret(self) -> "Settings":
        if not self.revenuecat_webhook_secret:
            raise ValueError("revenuecat_webhook_secret must be set (non-empty)")
        return self

    @model_validator(mode="after")
    def _validate_production_secrets(self) -> "Settings":
        is_prod = self.environment == "production"

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
