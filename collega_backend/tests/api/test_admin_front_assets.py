"""Console admin statique : chaque fichier référencé existe, pas d'innerHTML hors icônes, pas d'emoji."""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from httpx import AsyncClient

ADMIN = Path(__file__).resolve().parents[2] / "app/static/admin"
EMOJI = re.compile("[\U0001f300-\U0001faff☀-➿]")


def _js_files() -> list[Path]:
    return sorted((ADMIN / "js").rglob("*.js"))


def test_references_de_index_existent():
    html = (ADMIN / "index.html").read_text(encoding="utf-8")
    refs = re.findall(r'(?:href|src)="/admin/([^"]+)"', html)
    assert refs, "index.html doit référencer ses assets en /admin/…"
    for ref in refs:
        assert (ADMIN / ref).is_file(), ref


def test_imports_des_modules_existent():
    for path in _js_files():
        for ref in re.findall(
            r"""(?:from|import)\s*\(?\s*['"](\.{1,2}/[^'"]+)['"]""", path.read_text(encoding="utf-8")
        ):
            assert (path.parent / ref).resolve().is_file(), f"{path.name} → {ref}"


def test_polices_de_tokens_css_existent():
    css = (ADMIN / "css/tokens.css").read_text(encoding="utf-8")
    for ref in re.findall(r"url\('?\.\./([^')]+)'?\)", css):
        assert (ADMIN / ref).is_file(), ref


def test_admin_front_n_utilise_pas_innerhtml_hors_icones():
    for path in _js_files():
        if path.name == "icons.js":
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            if "innerHTML" in line:
                assert "ICONS[" in line, f"{path.name} : innerHTML hors icônes → {line.strip()}"


def test_aucun_emoji():
    for path in [*_js_files(), ADMIN / "index.html", *(ADMIN / "css").glob("*.css")]:
        assert not EMOJI.search(path.read_text(encoding="utf-8")), path.name


@pytest.mark.parametrize("path", ["/admin/", "/admin/js/main.js", "/admin/css/ui.css"])
async def test_servi_par_fastapi(client: AsyncClient, path: str):
    assert (await client.get(path)).status_code == 200


@pytest.mark.parametrize("path", ["/admin/", "/admin/js/main.js", "/admin/js/views/testeuse.js"])
async def test_jamais_servi_depuis_un_cache_perime(client: AsyncClient, path: str):
    # Modules ES sans numéro de version : après un déploiement, le navigateur (ou
    # Cloudflare) doit revalider chaque fichier au lieu de garder l'ancien écran.
    assert (await client.get(path)).headers["cache-control"] == "no-cache"
