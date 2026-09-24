"""Tests des validators de `app.core.config.Settings` — Story 7.3 T2.

Le validator `_validate_production_secrets` :
- raise `ValueError` (→ ValidationError) en mode `production` si secrets faibles
- log `WARNING` en mode `development` sans raise
"""

import logging

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def _base_settings_kwargs(**overrides):
    """Minimum valid settings, override per test."""
    base = dict(
        database_url="postgresql+asyncpg://test/test",
        redis_url="redis://test:6379/0",
        secret_key="a" * 32,
        claude_api_key="sk-ant-test1234567890",
        admin_password="strongpw",
        revenuecat_webhook_secret="real-secret",
    )
    base.update(overrides)
    return base


def _make_settings(**kwargs) -> Settings:
    # `_env_file=None` désactive la lecture du `.env` local (sinon ENVIRONMENT
    # ou autres variables pourraient polluer le test selon la machine dev).
    return Settings(_env_file=None, **kwargs)


class TestValidatorsProductionMode:
    def test_valid_production_settings_pass(self):
        s = _make_settings(environment="production", **_base_settings_kwargs())
        assert s.environment == "production"

    def test_refused_config_never_prints_secret_values(self):
        # Les logs du conteneur (affichés par deploy.sh en cas d'échec) ne doivent
        # contenir aucune valeur de variable : pydantic les recopie par défaut.
        with pytest.raises(ValidationError) as exc:
            _make_settings(
                environment="production",
                **_base_settings_kwargs(secret_key="short", revenuecat_webhook_secret="RC-SECRET-VALUE"),
            )
        assert "RC-SECRET-VALUE" not in str(exc.value)
        assert "sk-ant-test1234567890" not in str(exc.value)

    def test_short_secret_key_raises(self):
        with pytest.raises(ValidationError, match="SECRET_KEY"):
            _make_settings(environment="production", **_base_settings_kwargs(secret_key="short"))

    def test_default_secret_key_raises(self):
        with pytest.raises(ValidationError, match="SECRET_KEY"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(secret_key="change-me-in-production-use-at-least-32-chars"),
            )

    def test_empty_claude_key_raises(self):
        with pytest.raises(ValidationError, match="CLAUDE_API_KEY"):
            _make_settings(environment="production", **_base_settings_kwargs(claude_api_key=""))

    def test_malformed_claude_key_raises(self):
        with pytest.raises(ValidationError, match="CLAUDE_API_KEY"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(claude_api_key="not-a-real-key"),
            )

    def test_default_admin_password_raises(self):
        with pytest.raises(ValidationError, match="ADMIN_PASSWORD"):
            _make_settings(environment="production", **_base_settings_kwargs(admin_password="change-me"))

    def test_leftover_tester_variables_are_ignored(self, monkeypatch):
        # Chantier 5 (R1) : les TESTER_* restent dans le .env du NAS, jamais réécrit.
        monkeypatch.setenv("TESTER_USERNAME", "tester")
        monkeypatch.setenv("TESTER_PASSWORD", "change-me")
        s = _make_settings(environment="production", **_base_settings_kwargs())
        assert not hasattr(s, "tester_password")

    def test_default_webhook_secret_raises(self):
        with pytest.raises(ValidationError, match="REVENUECAT_WEBHOOK_SECRET"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(revenuecat_webhook_secret="change-me-in-production"),
            )

    def test_multiple_issues_listed_in_message(self):
        with pytest.raises(ValidationError) as exc_info:
            _make_settings(
                environment="production",
                **_base_settings_kwargs(secret_key="short", admin_password="change-me"),
            )
        msg = str(exc_info.value)
        assert "SECRET_KEY" in msg and "ADMIN_PASSWORD" in msg


class TestValidatorsDevelopmentMode:
    def test_weak_secrets_log_warning_no_raise(self, caplog):
        with caplog.at_level(logging.WARNING, logger="app.core.config"):
            _make_settings(
                environment="development",
                **_base_settings_kwargs(secret_key="short", admin_password="change-me"),
            )
        assert "DEV mode" in caplog.text
        assert "SECRET_KEY" in caplog.text
        assert "ADMIN_PASSWORD" in caplog.text

    def test_test_environment_accepted(self):
        s = _make_settings(environment="test", **_base_settings_kwargs())
        assert s.environment == "test"

    def test_valid_dev_settings_no_warning(self, caplog):
        with caplog.at_level(logging.WARNING, logger="app.core.config"):
            _make_settings(environment="development", **_base_settings_kwargs())
        # Aucune violation détectée → pas de warning DEV mode
        assert "DEV mode" not in caplog.text


class TestEnvironmentRequired:
    """Chantier 2 § 6 : `ENVIRONMENT` obligatoire, valeur dans {development, production, test}."""

    def test_missing_environment_refuses_to_start(self, monkeypatch):
        # La suite de tests définit ENVIRONMENT=test (conftest) : on l'enlève ici.
        monkeypatch.delenv("ENVIRONMENT", raising=False)
        with pytest.raises(ValidationError, match="environment"):
            _make_settings(**_base_settings_kwargs())

    @pytest.mark.parametrize("value", ["prod", "PRODUCTION", " production ", "staging", ""])
    def test_unknown_environment_refuses_to_start(self, value):
        # Une typo (`prod`) ne doit plus être traitée silencieusement comme dev.
        with pytest.raises(ValidationError, match="environment"):
            _make_settings(environment=value, **_base_settings_kwargs())

    def test_environment_from_env_var(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "production")
        s = _make_settings(**_base_settings_kwargs())
        assert s.environment == "production"


class TestStripAndStrictness:
    """Story 7.3 review — P2+P3+P5+P6 : strip whitespace + listes fermées."""

    def test_admin_password_with_trailing_space_rejected(self):
        # `ADMIN_PASSWORD="change-me-in-production "` (espace traînant) ne doit
        # PAS échapper au validator. Avant : égalité stricte → bypass possible.
        with pytest.raises(ValidationError, match="ADMIN_PASSWORD"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(admin_password="change-me-in-production "),
            )

    def test_admin_password_whitespace_only_rejected(self):
        # `ADMIN_PASSWORD=" "` (un espace seul) ne doit pas passer pour un vrai
        # secret en prod.
        with pytest.raises(ValidationError, match="ADMIN_PASSWORD"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(admin_password=" "),
            )

    def test_legit_secret_with_change_me_prefix_passes(self):
        # Avant le patch : `startswith("change-me")` rejetait à tort un secret
        # légitime préfixé `change-me-…`. La liste fermée corrige ce
        # false-positive.
        secret = "change-me-foo-" + "x" * 32  # 47 chars, pas dans la liste
        s = _make_settings(environment="production", **_base_settings_kwargs(secret_key=secret))
        assert s.secret_key == secret

    def test_legit_secret_containing_in_production_passes(self):
        # Avant le patch : `"in-production" in self.secret_key.lower()` rejetait
        # un secret de 32+ chars contenant cette substring. La liste fermée
        # corrige.
        secret = "my-real-secret-for-use-in-production-environment"  # 48 chars
        s = _make_settings(environment="production", **_base_settings_kwargs(secret_key=secret))
        assert s.secret_key == secret

    def test_claude_api_key_prefix_only_rejected(self):
        # Avant le patch : `startswith("sk-ant-")` acceptait `"sk-ant-"` (7 chars
        # nu) en prod. Désormais une longueur minimale est requise.
        with pytest.raises(ValidationError, match="CLAUDE_API_KEY"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(claude_api_key="sk-ant-"),
            )

    def test_secret_key_short_and_placeholder_reports_both(self):
        # Avant le patch : `if/elif` ne reportait qu'une seule violation à la
        # fois. Désormais deux contrôles indépendants → l'opérateur voit les
        # deux problèmes d'un coup.
        with pytest.raises(ValidationError) as exc_info:
            _make_settings(
                environment="production",
                **_base_settings_kwargs(secret_key="change-me"),  # placeholder + len 9 < 32
            )
        msg = str(exc_info.value)
        assert "must be ≥ 32 chars" in msg
        assert "default placeholder" in msg

    def test_webhook_secret_change_me_short_form_rejected(self):
        # Avant le patch : seul `"change-me-in-production"` (forme longue) était
        # détecté. `"change-me"` (forme courte) passait silencieusement.
        with pytest.raises(ValidationError, match="REVENUECAT_WEBHOOK_SECRET"):
            _make_settings(
                environment="production",
                **_base_settings_kwargs(revenuecat_webhook_secret="change-me"),
            )


def test_generation_concurrency_defaults_to_4_and_is_at_least_1():
    assert _make_settings(**_base_settings_kwargs()).generation_concurrency == 4
    with pytest.raises(ValidationError):
        _make_settings(**_base_settings_kwargs(generation_concurrency=0))
