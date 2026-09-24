"""Allègement du texte envoyé à Claude (chantier 4, spec § 5).

`clean_for_prompt` est pure et n'est appliquée qu'au texte envoyé à Claude :
l'empreinte (`fingerprint.item_hash`) et `item_texts` restent calculés sur le
texte brut (spec § 5). Toute modification de cette fonction impose
d'incrémenter `PROMPT_VERSION` (app.services.generation.claude_client) pour
que les items déjà vus soient régénérés.
"""

from __future__ import annotations

import re
import unicodedata

from app.services.ocr.text_normalize import WATERMARK_PATTERN

# OCR : glyphe non mappé rendu par pdfplumber/pdfminer sous la forme « (cid:181) »,
# isolé ou accolé à du texte (« Tumeurs(cid:415) du foie ») — retiré sans toucher
# au reste de la ligne.
_CID_MARKER = re.compile(r"\(cid:\d+\)")

# Numéro de page seul, avec ou sans préfixe/format usuel : « 233 », « Page 12 », « 12 / 436 », « 13 sur 40 ».
_PAGE_NUMBER_LINE = re.compile(r"^(page\s*)?\d+(\s*(/|sur)\s*\d+)?$", re.IGNORECASE)

# Ligne d'un seul caractère ou d'un seul fragment (« n », « - », « ed ») : au plus 2
# caractères non-espace.
_MAX_FRAGMENT_NON_SPACE_CHARS = 2

# Rang isolé sur sa ligne (pdfplumber sépare parfois « 3. Dépistage… » / « A » /
# « 3.1 … » dans un tableau d'objectifs) : jamais retiré par la règle des fragments,
# même s'il tient en 1-2 caractères non-espace. Casse significative (rang normalisé
# ailleurs, ici c'est le symbole lu dans le PDF).
_RANG_MARKERS = frozenset({"A", "B", "C", "A*", "B*"})

# En-tête/pied répété : ligne normalisée présente sur au moins cette part des pages
# d'un item d'au moins ce nombre de pages (spec § 5).
_MIN_PAGES_FOR_HEADER_RULE = 3
_HEADER_MIN_SHARE = 0.5


def _normalize_line(line: str) -> str:
    """Ligne comparable indépendamment de la casse, des accents et des espaces."""
    s = unicodedata.normalize("NFKD", line.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", s).strip()


def _is_fragment(line: str) -> bool:
    if line in _RANG_MARKERS:
        return False
    return len(re.sub(r"\s", "", line)) <= _MAX_FRAGMENT_NON_SPACE_CHARS


def _page_lines(text: str) -> list[str]:
    """Lignes d'une page, cid/filigranes/fragments/numéros de page seuls retirés ;
    les lignes déjà vides dans le texte brut sont conservées (marqueurs de saut de
    paragraphe, réduits ensuite) — une ligne qui ne devient vide qu'après retrait
    d'un `(cid:NNN)` disparaît sans laisser de vide, ce n'est pas un saut de paragraphe."""
    lines: list[str] = []
    for raw in text.splitlines():
        stripped = raw.strip()
        if stripped == "":
            lines.append("")
            continue
        line = _CID_MARKER.sub("", stripped).strip()
        if line == "":
            continue
        if WATERMARK_PATTERN.search(line):
            continue
        if _PAGE_NUMBER_LINE.match(line) or _is_fragment(line):
            continue
        lines.append(line)
    return lines


def _repeated_header_footer_lines(pages_lines: list[list[str]]) -> set[str]:
    """Lignes normalisées présentes sur ≥ 50 % des pages d'un item d'au moins 3 pages."""
    if len(pages_lines) < _MIN_PAGES_FOR_HEADER_RULE:
        return set()
    counts: dict[str, int] = {}
    for lines in pages_lines:
        for norm in {_normalize_line(line) for line in lines if line}:
            counts[norm] = counts.get(norm, 0) + 1
    threshold = _HEADER_MIN_SHARE * len(pages_lines)
    return {norm for norm, n in counts.items() if n >= threshold}


def _collapse_blank_runs(lines: list[str]) -> list[str]:
    """Réduit les suites de lignes vides à une, et retire les vides en tête/fin."""
    result: list[str] = []
    for line in lines:
        if line == "" and (not result or result[-1] == ""):
            continue
        result.append(line)
    while result and result[-1] == "":
        result.pop()
    return result


def clean_for_prompt(pages: list[str]) -> str:
    """Texte allégé d'un item envoyé à Claude (spec § 5) : filigranes, `(cid:NNN)`,
    lignes d'un seul caractère/fragment, numéros de page seuls, en-têtes/pieds
    répétés retirés ; suites de lignes vides réduites à une."""
    pages_lines = [_page_lines(page) for page in pages]
    repeated = _repeated_header_footer_lines(pages_lines)

    out_lines: list[str] = []
    for lines in pages_lines:
        out_lines.extend(line for line in lines if line == "" or _normalize_line(line) not in repeated)
        out_lines.append("")  # frontière de page, réduite avec les lignes vides voisines

    return "\n".join(_collapse_blank_runs(out_lines))
