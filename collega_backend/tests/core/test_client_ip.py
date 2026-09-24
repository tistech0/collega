"""Adresse client fiable (chantier 2 § 4) : en-têtes de proxy lus seulement derrière un proxy de confiance."""

from __future__ import annotations

import pytest
from pydantic import ValidationError
from starlette.requests import Request

from app.core.config import Settings, settings
from app.core.limiter import get_client_ip, user_id_key

NPM = "172.18.0.5"  # réseau Docker de Nginx Proxy Manager (dans 172.16.0.0/12)


def _request(client_host: str | None, headers: dict[str, str] | None = None) -> Request:
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": [(k.lower().encode(), v.encode()) for k, v in (headers or {}).items()],
        "client": (client_host, 1234) if client_host is not None else None,
    }
    return Request(scope)


@pytest.fixture(autouse=True)
def _default_trusted(monkeypatch):
    monkeypatch.setattr(settings, "trusted_proxy_ips", ["172.16.0.0/12"])


class TestTrustedProxy:
    def test_cf_connecting_ip_prioritaire(self):
        req = _request(NPM, {"CF-Connecting-IP": "203.0.113.7", "X-Forwarded-For": "1.1.1.1, 198.51.100.2"})
        assert get_client_ip(req) == "203.0.113.7"

    def test_dernier_element_de_x_forwarded_for(self):
        req = _request(NPM, {"X-Forwarded-For": "6.6.6.6, 198.51.100.2"})
        assert get_client_ip(req) == "198.51.100.2"

    def test_x_forwarded_for_un_seul_element(self):
        assert get_client_ip(_request(NPM, {"X-Forwarded-For": " 198.51.100.2 "})) == "198.51.100.2"

    def test_x_forwarded_for_elements_vides_ignores(self):
        assert get_client_ip(_request(NPM, {"X-Forwarded-For": "6.6.6.6, 198.51.100.2, "})) == "198.51.100.2"

    def test_sans_en_tete_adresse_du_proxy(self):
        assert get_client_ip(_request(NPM)) == NPM

    def test_cf_connecting_ip_invalide_ignore(self):
        req = _request(NPM, {"CF-Connecting-IP": "pas-une-ip", "X-Forwarded-For": "198.51.100.2"})
        assert get_client_ip(req) == "198.51.100.2"

    def test_cf_connecting_ip_ipv6(self):
        assert get_client_ip(_request(NPM, {"CF-Connecting-IP": "2001:db8::1"})) == "2001:db8::1"


class TestUntrustedClient:
    def test_en_tetes_ignores_hors_proxy_de_confiance(self):
        req = _request("203.0.113.50", {"CF-Connecting-IP": "1.2.3.4", "X-Forwarded-For": "5.6.7.8"})
        assert get_client_ip(req) == "203.0.113.50"

    def test_jamais_le_premier_element_falsifiable(self):
        req = _request("203.0.113.50", {"X-Forwarded-For": "6.6.6.6"})
        assert get_client_ip(req) != "6.6.6.6"

    def test_hors_du_reseau_docker(self):
        # 172.32.0.1 est juste au-delà de 172.16.0.0/12.
        assert get_client_ip(_request("172.32.0.1", {"X-Forwarded-For": "5.6.7.8"})) == "172.32.0.1"

    def test_hote_non_ip(self):
        assert get_client_ip(_request("testclient", {"X-Forwarded-For": "5.6.7.8"})) == "testclient"

    def test_sans_client(self):
        assert get_client_ip(_request(None, {"X-Forwarded-For": "5.6.7.8"})) == "unknown"

    def test_liste_vide_aucun_proxy_de_confiance(self, monkeypatch):
        monkeypatch.setattr(settings, "trusted_proxy_ips", [])
        assert get_client_ip(_request(NPM, {"CF-Connecting-IP": "1.2.3.4"})) == NPM

    def test_plusieurs_reseaux(self, monkeypatch):
        monkeypatch.setattr(settings, "trusted_proxy_ips", ["10.0.0.0/8", "192.168.1.10"])
        assert get_client_ip(_request("192.168.1.10", {"X-Forwarded-For": "5.6.7.8"})) == "5.6.7.8"
        assert get_client_ip(_request("10.1.2.3", {"CF-Connecting-IP": "1.2.3.4"})) == "1.2.3.4"


class TestUserIdKey:
    def test_utilisatrice_authentifiee(self):
        req = _request("203.0.113.50")
        req.state.user_id = "abc"
        assert user_id_key(req) == "user:abc"

    def test_repli_sur_l_ip_fiable(self):
        assert user_id_key(_request(NPM, {"X-Forwarded-For": "6.6.6.6, 198.51.100.2"})) == "ip:198.51.100.2"


class TestTrustedProxySetting:
    @staticmethod
    def _settings(**kw) -> Settings:
        base = dict(
            database_url="postgresql+asyncpg://t/t",
            redis_url="redis://t:6379/0",
            secret_key="a" * 32,
            claude_api_key="sk-ant-test1234567890",
            admin_password="strongpw",
            revenuecat_webhook_secret="real-secret",
        )
        base.update(kw)
        return Settings(_env_file=None, **base)

    def test_defaut_reseau_docker(self, monkeypatch):
        monkeypatch.delenv("TRUSTED_PROXY_IPS", raising=False)
        assert self._settings().trusted_proxy_ips == ["172.16.0.0/12"]

    def test_variable_separee_par_des_virgules(self, monkeypatch):
        monkeypatch.setenv("TRUSTED_PROXY_IPS", "10.0.0.0/8, 192.168.1.10 ,")
        assert self._settings().trusted_proxy_ips == ["10.0.0.0/8", "192.168.1.10"]

    def test_variable_vide_aucun_proxy(self, monkeypatch):
        monkeypatch.setenv("TRUSTED_PROXY_IPS", "")
        assert self._settings().trusted_proxy_ips == []

    def test_reseau_invalide_refuse_au_demarrage(self, monkeypatch):
        monkeypatch.setenv("TRUSTED_PROXY_IPS", "172.16.0.0/12,pas-un-reseau")
        with pytest.raises(ValidationError):
            self._settings()
