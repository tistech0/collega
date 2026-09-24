"""Tests GET /v1/admin/config et PATCH /v1/admin/config."""

from __future__ import annotations

from unittest.mock import patch

from httpx import AsyncClient

ADMIN_AUTH = ("admin", "testpass")


class TestGetConfig:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.get("/v1/admin/config")
        assert resp.status_code == 401

    async def test_returns_current_config(self, client: AsyncClient):
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3

            resp = await client.get("/v1/admin/config", auth=ADMIN_AUTH)

        assert resp.status_code == 200
        body = resp.json()
        assert "data" in body
        assert body["data"]["reload_count_max"] == 2
        assert body["data"]["monthly_reloads_max"] == 3

    async def test_response_has_data_wrapper(self, client: AsyncClient):
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3
            resp = await client.get("/v1/admin/config", auth=ADMIN_AUTH)
        assert "data" in resp.json()


class TestPatchConfig:
    async def test_401_without_credentials(self, client: AsyncClient):
        resp = await client.patch("/v1/admin/config", json={"reload_count_max": 5})
        assert resp.status_code == 401

    async def test_update_reload_count_max(self, client: AsyncClient):
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3

            resp = await client.patch(
                "/v1/admin/config",
                json={"reload_count_max": 5},
                auth=ADMIN_AUTH,
            )

        assert resp.status_code == 200
        assert mock_settings.reload_count_max == 5
        assert mock_settings.monthly_reloads_max == 3

    async def test_update_monthly_reloads_max(self, client: AsyncClient):
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3

            resp = await client.patch(
                "/v1/admin/config",
                json={"monthly_reloads_max": 10},
                auth=ADMIN_AUTH,
            )

        assert resp.status_code == 200
        assert mock_settings.monthly_reloads_max == 10
        assert mock_settings.reload_count_max == 2

    async def test_update_both_fields(self, client: AsyncClient):
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3

            resp = await client.patch(
                "/v1/admin/config",
                json={"reload_count_max": 7, "monthly_reloads_max": 15},
                auth=ADMIN_AUTH,
            )

        assert resp.status_code == 200
        body = resp.json()["data"]
        assert body["reload_count_max"] == 7
        assert body["monthly_reloads_max"] == 15

    async def test_partial_update_preserves_other_field(self, client: AsyncClient):
        """Envoyer seulement reload_count_max ne doit pas toucher monthly_reloads_max."""
        with patch("app.api.v1.admin.settings") as mock_settings:
            mock_settings.admin_username = "admin"
            mock_settings.admin_password = "testpass"
            mock_settings.reload_count_max = 2
            mock_settings.monthly_reloads_max = 3

            resp = await client.patch(
                "/v1/admin/config",
                json={"reload_count_max": 4},
                auth=ADMIN_AUTH,
            )

        assert resp.status_code == 200
        assert mock_settings.reload_count_max == 4
        assert mock_settings.monthly_reloads_max == 3
