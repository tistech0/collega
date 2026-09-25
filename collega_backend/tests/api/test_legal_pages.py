"""Pages publiques exigées par App Store Connect (confidentialité, support), servies
sans authentification et hors Cloudflare Access (bypass sur /legal)."""

from __future__ import annotations

from pathlib import Path

import pytest

BACKEND_LEGAL = Path(__file__).resolve().parents[2] / "app" / "static" / "legal"
APP_LEGAL = Path(__file__).resolve().parents[3] / "collega_app" / "assets" / "legal"


@pytest.mark.parametrize("path", ["/legal/privacy", "/legal/terms", "/legal/support"])
async def test_page_publique_html_avec_l_editeur(client, path):
    resp = await client.get(path)
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/html")
    assert "contact@matthislesur.com" in resp.text
    assert "<script" not in resp.text


async def test_confidentialite_rendue_depuis_le_markdown(client):
    resp = await client.get("/legal/privacy")
    assert "<h1>Politique de Confidentialité</h1>" in resp.text
    assert "Matthis Lesur" in resp.text


@pytest.mark.parametrize("name", ["privacy.md", "cgu.md"])
def test_textes_identiques_a_ceux_de_l_app(name):
    if not APP_LEGAL.exists():
        pytest.skip("dépôt partiel : textes de l'app absents")
    assert (BACKEND_LEGAL / name).read_bytes() == (APP_LEGAL / name).read_bytes(), (
        f"Recopier collega_app/assets/legal/{name} dans collega_backend/app/static/legal/"
    )
