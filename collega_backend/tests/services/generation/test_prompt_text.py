"""Tests de `clean_for_prompt` (chantier 4, spec § 5)."""

import json
import re
import unicodedata
from pathlib import Path

import pytest

from app.services.content.fingerprint import item_hash
from app.services.generation.prompt_text import _CID_MARKER, clean_for_prompt
from app.services.ocr.text_normalize import WATERMARK_PATTERN

FIXTURES = Path(__file__).resolve().parents[2] / "fixtures"


def test_clean_text_is_unchanged():
    pages = ["Item 304\nTumeurs du foie\nLe foie est un organe volumineux"]
    assert clean_for_prompt(pages) == "Item 304\nTumeurs du foie\nLe foie est un organe volumineux"


@pytest.mark.parametrize(
    "watermark_line",
    [
        "Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com abonnez-vous",
        "Il a été diffusé exclusivement et gratuitement sur le forum © SBA-MEDECINE",
        "pour plus des livres médicaux gratuits rejoignez-nous sur www.sba-medecine.com",
        "Faille_V2",
        "POUR AVOIR PLUS D'EXCLUSIVITÉS REJOIGNEZ AMIS-MED.COM",  # casse
    ],
)
def test_watermark_lines_removed(watermark_line):
    pages = [f"Le foie est volumineux\n{watermark_line}\nMétastases hépatiques"]
    assert watermark_line not in clean_for_prompt(pages)
    assert "Le foie est volumineux" in clean_for_prompt(pages)


def test_cid_marker_removed_inside_line():
    pages = ["Tumeurs(cid:415) du foie\nLe foie est volumineux"]
    assert clean_for_prompt(pages) == "Tumeurs du foie\nLe foie est volumineux"


def test_cid_only_line_removed():
    pages = ["Le foie est volumineux\n(cid:181)\nMétastases hépatiques"]
    assert clean_for_prompt(pages) == "Le foie est volumineux\nMétastases hépatiques"


@pytest.mark.parametrize("fragment_line", ["n", "-", "ed", "a."])
def test_fragment_lines_removed(fragment_line):
    pages = [f"Le foie est volumineux\n{fragment_line}\nMétastases hépatiques"]
    assert clean_for_prompt(pages) == "Le foie est volumineux\nMétastases hépatiques"


@pytest.mark.parametrize("page_number_line", ["233", "Page 12", "12 / 436", "13 sur 40", "page 7"])
def test_page_number_alone_removed(page_number_line):
    pages = [f"Le foie est volumineux\n{page_number_line}\nMétastases hépatiques"]
    assert clean_for_prompt(pages) == "Le foie est volumineux\nMétastases hépatiques"


def test_number_inside_content_line_is_kept():
    """Un numéro seul sur sa ligne est retiré, mais un chiffre au milieu d'une ligne de
    contenu (dose, grade…) est conservé."""
    pages = ["Dose 233 mg par jour\nGrade 3\n233"]
    cleaned = clean_for_prompt(pages)
    assert "Dose 233 mg par jour" in cleaned
    assert "Grade 3" in cleaned
    assert "\n233" not in cleaned and not cleaned.startswith("233")


def test_repeated_header_removed_at_3_pages_and_above_half():
    """En-tête identique après normalisation, ≥ 50 % des pages d'un item d'au moins 3 pages."""
    pages = [
        "Item 304 - Tumeurs du foie\nLe foie est volumineux",
        "ITEM 304 - TUMEURS DU FOIE\nMétastases hépatiques",
        "Autre page sans en-tête\nConclusion du chapitre",
    ]
    cleaned = clean_for_prompt(pages)
    assert "item 304" not in cleaned.lower()
    assert "Le foie est volumineux" in cleaned
    assert "Métastases hépatiques" in cleaned
    assert "Autre page sans en-tête" in cleaned


def test_repeated_line_kept_below_2_pages_threshold():
    """La règle des en-têtes répétés ne s'applique qu'à partir de 3 pages."""
    pages = [
        "Item 304 - Tumeurs du foie\nLe foie est volumineux",
        "Item 304 - Tumeurs du foie\nMétastases hépatiques",
    ]
    cleaned = clean_for_prompt(pages)
    assert cleaned.lower().count("item 304") == 2


def test_repeated_line_kept_below_50_percent():
    pages = [
        "Item 304 - Tumeurs du foie\nLe foie est volumineux",
        "Autre page 1\nConclusion",
        "Autre page 2\nSuite",
    ]
    cleaned = clean_for_prompt(pages)
    assert "item 304" in cleaned.lower()


def test_blank_line_runs_reduced_to_one():
    pages = ["Titre\n\n\n\nParagraphe un", "\n\n\nParagraphe deux\n\n\n"]
    assert clean_for_prompt(pages) == "Titre\n\nParagraphe un\n\nParagraphe deux"


def test_item_hash_stays_computed_on_raw_text():
    """`fingerprint.item_hash` ne doit jamais être calculé sur le texte nettoyé
    (spec § 5) : le nettoyage change le texte, donc changerait l'empreinte."""
    pages = [
        "Item 304 - Tumeurs du foie\n"
        "Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com\n"
        "233\nLe foie est volumineux",
        "Item 304 - Tumeurs du foie\nMétastases hépatiques\n234",
        "Item 304 - Tumeurs du foie\nConclusion\n235",
    ]
    raw_hash = item_hash(pages)

    # Un appel à clean_for_prompt ne modifie pas le texte brut ni ce que produit item_hash.
    clean_for_prompt(pages)
    assert item_hash(pages) == raw_hash

    # Hasher le texte nettoyé (ce qu'il ne faut jamais faire) donne une empreinte différente :
    # la garde-fou de cette empreinte, c'est qu'on ne l'appelle qu'avec `pages` brut.
    assert item_hash([clean_for_prompt(pages)]) != raw_hash


# ── Fixtures privées (sous droits, hors git ; ignorées si absentes — cf. tests/services/ocr) ──

COLLEGES = [3, 12, 34]


def _norm(line: str) -> str:
    s = unicodedata.normalize("NFKD", line.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", s).strip()


def _digit_and_3_letters(line: str) -> bool:
    return any(c.isdigit() for c in line) and sum(c.isalpha() for c in line) >= 3


def _repeated_lines(pages_text: list[str]) -> set[str]:
    """Reproduction indépendante de la règle des en-têtes/pieds répétus (≥ 3 pages, ≥ 50 %),
    pour ne pas prendre pour acquis l'implémentation testée."""
    if len(pages_text) < 3:
        return set()
    counts: dict[str, int] = {}
    for text in pages_text:
        seen = {_norm(line.strip()) for line in text.splitlines() if line.strip()}
        for norm in seen:
            counts[norm] = counts.get(norm, 0) + 1
    threshold = 0.5 * len(pages_text)
    return {norm for norm, n in counts.items() if n >= threshold}


@pytest.fixture(params=COLLEGES)
def college_data(request) -> dict:
    path = FIXTURES / "private" / f"college_{request.param}.json"
    if not path.exists():
        pytest.skip(f"fixture privée absente : {path.name}")
    return json.loads(path.read_text())


def test_digit_and_letters_content_lines_survive_cleaning(college_data):
    """Une ligne de contenu qui porte un chiffre (dose, grade, numéro dans le texte…) et au
    moins 3 lettres ne doit jamais disparaître — sauf si elle EST l'en-tête/pied répété de
    l'item (retrait volontaire, spec § 5), vérifié ici indépendamment de l'implémentation."""
    pages = {p["page_number"]: p["text"] for p in college_data["pages"]}
    checked = 0
    for item in college_data["items"]:
        item_pages_text = [pages[p] for p in range(item["start_page"], item["end_page"] + 1) if p in pages]
        if not item_pages_text:
            continue
        cleaned = clean_for_prompt(item_pages_text)
        cleaned_norm = _norm(cleaned)
        repeated = _repeated_lines(item_pages_text)
        for text in item_pages_text:
            for raw in text.splitlines():
                # (cid:NNN) est un artefact OCR retiré par clean_for_prompt (spec § 5) :
                # un chiffre qui n'existe que dans ce marqueur n'est pas du contenu.
                line = _CID_MARKER.sub("", raw.strip()).strip()
                if not line or not _digit_and_3_letters(line):
                    continue
                if WATERMARK_PATTERN.search(line):
                    continue  # filigrane : retrait volontaire (spec § 5), pas du contenu
                if _norm(line) in repeated:
                    continue  # en-tête/pied répété : retrait volontaire
                checked += 1
                assert _norm(line) in cleaned_norm, f"ligne de contenu perdue (item {item['item_number']})"
    assert checked > 0


def test_report_char_reduction_per_college(college_data, capsys):
    """Réduction de caractères par collège (chantier 4, § 5) — chiffres seuls, jamais de texte."""
    pages = {p["page_number"]: p["text"] for p in college_data["pages"]}
    raw_chars = 0
    clean_chars = 0
    for item in college_data["items"]:
        item_pages_text = [pages[p] for p in range(item["start_page"], item["end_page"] + 1) if p in pages]
        if not item_pages_text:
            continue
        raw_chars += sum(len(t) for t in item_pages_text)
        clean_chars += len(clean_for_prompt(item_pages_text))
    ref_id = college_data["college_ref_id"]
    reduction_pct = 100 * (raw_chars - clean_chars) / raw_chars if raw_chars else 0
    with capsys.disabled():
        print(f"\ncollège {ref_id} : {raw_chars} -> {clean_chars} caractères ({reduction_pct:.1f} % de réduction)")
    assert clean_chars <= raw_chars
