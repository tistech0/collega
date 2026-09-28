"""Assets partagés app → console : noms de collèges et icônes générés et à jour."""

from app.core.college_catalog import COLLEGE_NAMES, college_name
from scripts.gen_admin_assets import CATALOG_DART, generated_files, main


def test_fichiers_generes_a_jour():
    assert main(["--check"]) == 0, "lancer : python -m scripts.gen_admin_assets"


def test_noms_de_colleges():
    assert COLLEGE_NAMES[4] == "Cardiologie"
    assert college_name(4) == "Cardiologie"
    assert college_name(999) == "Collège n°999"


def test_toutes_les_entrees_du_catalogue_sont_reprises():
    source = CATALOG_DART.read_text(encoding="utf-8")
    assert len(COLLEGE_NAMES) == source.count("CollegeCatalogEntry(refId:")


def test_icones_en_currentcolor():
    icons_js = next(content for path, content in generated_files() if path.name == "icons.js")
    assert "thumbDown:" in icons_js and "euro:" in icons_js and "settings:" in icons_js
    assert 'stroke="#000"' not in icons_js and 'stroke="currentColor"' in icons_js
