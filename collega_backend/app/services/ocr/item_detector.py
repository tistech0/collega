"""Découpage d'un collège en items ECNi et rang de leurs objectifs (chantier 4, spec § 4).

Chaque page est classée (item N | section hors item | blanche) par une machine à états
sur des signaux par page. Objectif : chaque item reçoit toutes ses pages et seulement
les siennes ; le rapport de découpage dit où va chaque page (aucune page perdue).

Règles (détail et cas réels : analyse du chantier 4, § 4) :
  R0  normalisation : lignes de filigrane retirées, lignes « TTuummeeuurrss » dédoublées ;
      page blanche si moins de 40 caractères utiles.
  R1  en-tête « Item N » dans les 5 premières lignes ; préfixes « • », « w », « - / »,
      formes abîmées « tem N », « em N » ; chiffres coupés « 21 2 » → candidats [212, 21] ;
      « 359 bis » → 359.
  R2  « OBJECTIFS : N° x » ouvre l'item x (signal fort).
  R3  page d'ouverture (signal fort) : en-tête R1 et 1re ligne « CHAPITRE » (Elsevier),
      1re ligne « Collège des Enseignants … » (CEP) ou tableau « Rang … Rubrique ».
  R4  ensemble K des numéros sûrs : sommaire, OBJECTIFS, ouvertures fortes, en-têtes répétés
      ≥ 2 fois (sauf préfixe tronqué d'un numéro sûr) ; restreint au référentiel officiel
      s'il est fourni et complet. Un en-tête se résout : joint ∈ K, sinon item courant si un candidat
      en est le préfixe, sinon autre candidat ∈ K, sinon rien (warning).
  R5  un en-tête ≠ item courant n'ouvre un item que s'il est dans K, confirmé sur une des
      4 pages suivantes et pas déjà ouvert.
  R6  une page dont le début égale le titre connu (référentiel, sommaire, OBJECTIFS) d'un
      item de K pas encore ouvert ouvre cet item.
  R7  sections hors item (sommaire, préface… seulement avant le 1er item ; « CHAPITRE » sans
      item, dossiers progressifs, entraînement, index, corrigés partout) : ferment l'item.
  R8  un item fermé ne se rouvre pas par un signal faible ; une réouverture par un signal
      fort concatène les pages (un item par numéro) et est signalée.
  R9  pages blanches neutres : un item finit à sa dernière page de contenu, une page
      blanche interne y reste.
  R10 rapport : chaque page → item | section | blanche, avec ses signaux, et les warnings.

Rang (analyse § 3) : par objectif, dans le tableau « Rang Rubrique » de la page d'ouverture
et des 2 suivantes. Les pictogrammes des scans sont lus comme des lettres rondes : noirs
{A, A*, O, 0, G, ©, @} → A, bleus {B, B*, Q, □, s} → B, autre → inconnu. Dans les tableaux
pdfplumber, la colonne de rang est trouvée par ses valeurs (≥ 60 % de A/B/C).
Rang d'item : A si au moins un objectif A, sinon B si au moins un B, sinon A (warning).
"""

from __future__ import annotations

import json
import logging
import re
import unicodedata
from dataclasses import dataclass, field
from typing import Literal

from app.services.ocr.item_titles import clean_title, is_valid_title
from app.services.ocr.text_normalize import undouble

logger = logging.getLogger(__name__)

RangType = Literal["A", "B", "C"]
PageKind = Literal["item", "section", "blank"]
PageTables = list[list[list[str]]]  # list[table] → table = list[row] → row = list[cell]

# ── R0 ────────────────────────────────────────────────────────────────────────
_WATERMARK = re.compile(
    r"Pour avoir plus d.exclusivit|amis-med\.com|Faille_V2|livres m.dicaux gratuits|sba-m.decine"
    r"|diffus. exclusivement",
    re.IGNORECASE,
)
_BLANK_MAX_CHARS = 40

# ── R1 ────────────────────────────────────────────────────────────────────────
_HEADER_LINES = 5
_HEADER_ITEM = re.compile(
    r"^(?:[\W_]{0,4}|w\s+|-\s*/\s*)(?:i?t?em)\s*n?°?\s*((?:\d\s?){1,3})(\s*bis)?\b", re.IGNORECASE
)

# ── R2 / R3 ───────────────────────────────────────────────────────────────────
# « OBJECTIFS: N° 304. Tumeurs du foie… » (variantes OCR : « OBJECTIFS : », « N"o300. »)
_OBJECTIFS = re.compile(r"OBJECTIFS?\s*:?\s*N\s*[°º\"'o]{0,3}\s*(\d{1,3})\s*[.\-–:]?[ \t]*([^\n]*)")
_RANG_TABLE = re.compile(r"\bRang\b.{0,40}\bRubrique\b", re.IGNORECASE)
_CHAPITRE = re.compile(r"^CHAPITRE\b")
_CEP_FIRST_LINE = re.compile(r"Coll[èe]ge des Enseignants")
_RANG_TABLE_LINES = 40

# ── R4 : sommaire ─────────────────────────────────────────────────────────────
_TOC_ITEM_LINE = re.compile(r"(?im)^\s*(?:\d+\s+)?item\s*_?(\d{1,3})")
_TOC_LEADER_LINE = re.compile(r"\.{6,}|…")
_TOC_MIN_LEADERS = 4
_TOC_MIN_ITEMS = 3
_CONFIRM_PAGES = 4
_R6_TITLE_MIN = 10
_R6_TITLE_PREFIX = 25
# Le référentiel officiel ne restreint K que s'il est complet (367 items EDN, marge pour
# les numéros retirés) ; un référentiel partiel sert seulement aux titres (R6).
_COMPLETE_REFERENTIAL = 300

# ── R7 ────────────────────────────────────────────────────────────────────────
_SECTION_PATTERNS = [
    ("sommaire", re.compile(r"^\s*(sommaire|table des mati[èe]res)\b", re.IGNORECASE)),
    ("préface", re.compile(r"^\s*pr[ée]face\b", re.IGNORECASE)),
    ("introduction du livre", re.compile(r"^\s*introduction\s*$", re.IGNORECASE)),
    ("auteurs", re.compile(r"^\s*(les auteurs|collaborateurs\b)", re.IGNORECASE)),
    ("note de l'éditeur", re.compile(r"^\s*(note de l.[ée]diteur|compl[ée]ments en ligne)", re.IGNORECASE)),
    ("abréviations", re.compile(r"^\s*abr[ée]viations\b", re.IGNORECASE)),
    ("dossiers progressifs", re.compile(r"^\s*(dossiers? (cliniques )?progressifs|entra[îi]nement)\b", re.IGNORECASE)),
    ("index", re.compile(r"^\s*index\s*$", re.IGNORECASE)),
    ("corrigés", re.compile(r"^\s*(corrig[ée]s|r[ée]ponses aux (qcm|questions))\b", re.IGNORECASE)),
]
# R7 bis : liminaires, reconnues seulement avant le 1er item.
_FRONT_MATTER = frozenset(
    {"sommaire", "préface", "introduction du livre", "auteurs", "note de l'éditeur", "abréviations"}
)
_CHAPTER_WITHOUT_ITEM = "chapitre sans item"
_DOSSIERS = "dossiers progressifs"
_FRONT_LABEL = "liminaire"
_UNASSIGNED = "non rattachée"

# ── Rang (§ 3) ────────────────────────────────────────────────────────────────
# En-tête du tableau d'objectifs : « Rubrique » en début de ligne, précédé de « Rang » ou suivi
# de « Intitulé ». Plus large que `rang\W*rubrique` : l'OCR des scans abîme la 1re colonne
# (« Rang__ Rubrique », « Ra~g Rubrique », « 1 Rang j Rubrique », « ~ Rubrique Intitulé »).
_RUBRIQUE = "rubrique"
_RUBRIQUE_MAX_POSITION = 24
_RANG_BEFORE_RUBRIQUE = re.compile(r"ng[\W_]")
_RUBRIQUES = (
    r"(Définition|Diagnostic|Étiologie|Etiologie|Prise|Examens?|Identifier|Contenu|Épidémio|Epidémio|Prévalence"
    r"|Élé|Elé|Élts|Elts|Suivi|Physio|Facteurs|Pronostic|Situations?|Terminologie|Ex\b|Surveillance|Évaluation"
    r"|Evaluation|Dépistage|Prévention|Traitement|Classification|Moyens|Anatomie|Histoire|Examen|Formes"
    r"|Principes|Complications)"
)
_OBJECTIVE_ROW = re.compile(r"^(\S{1,3})\s+" + _RUBRIQUES)
_GLYPHS_A = frozenset({"A", "A*", "O", "0", "G", "©", "@"})  # pictogramme noir
_GLYPHS_B = frozenset({"B", "B*", "Q", "□", "s"})  # pictogramme bleu
# Fin du tableau d'objectifs : 1re section du cours (« I. Introduction », « 1. … »)
_COURSE_HEADING = re.compile(r"^(?:[IVX]+|\d+)\.\s")
_RANG_PAGES = 3
_RANG_VALUES = frozenset({"A", "B", "C"})
_RANG_COLUMN_MIN_RATIO = 0.6

# ── Titres (inchangés, story 8.0) ─────────────────────────────────────────────
# Préfixe « Chapitre 18 : » d'une entrée de sommaire (y compris OCR abîmé « C' a ire 13 : »)
_TOC_CHAPTER_PREFIX = re.compile(r"^[^:\d]{1,15}?\d+\s*:\s*")
_TOC_LEADERS = re.compile(r"[.·…\s]{3,}[\s\-\d]*$")
# Entrée « Item N » d'un sommaire (titres) : motif strict, en tout début de ligne
_TOC_TITLE_ITEM = re.compile(r"^[.,'’ \t]{0,3}item\s*n?°?\s*(\d{1,3})\b", re.IGNORECASE)
_TOC_STRICT_ITEM = re.compile(r"^item\s*n?°?\s*(\d{1,3})\b", re.IGNORECASE | re.MULTILINE)
_MAX_TITLE_LINES = 3
_TABLE_HEADER_LINE = re.compile(r"\s*(?:rang|rubrique)\b", re.IGNORECASE)
_MIN_ITEM_PAGES = 2


# ── Structures publiques ──────────────────────────────────────────────────────


@dataclass
class DetectedItem:
    item_number: int
    rang: RangType
    chapter_title: str
    ocr_text: str
    start_page: int
    end_page: int
    ocr_confidence_score: float
    word_confidences: list[float] = field(default_factory=list)
    # Pages de l'item, triées (une page blanche interne y reste, R9) ; start/end = min/max.
    pages: list[int] = field(default_factory=list)
    objectives_a: int = 0
    objectives_b: int = 0


@dataclass
class PageAssignment:
    """Place d'une page dans le découpage (R10). Aucun texte de page : numéros et libellés."""

    page: int
    kind: PageKind
    item_number: int | None = None
    label: str | None = None
    signals: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        data: dict = {"page": self.page, "kind": self.kind}
        if self.item_number is not None:
            data["item_number"] = self.item_number
        if self.label is not None:
            data["label"] = self.label
        data["signals"] = self.signals
        return data


@dataclass
class SegmentationReport:
    pages: list[PageAssignment] = field(default_factory=list)
    items: list[dict] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def sections(self) -> list[dict]:
        """Sections hors item : une entrée par libellé, pages en plages (« 2-3,40 »)."""
        by_label: dict[str, list[int]] = {}
        for p in self.pages:
            if p.kind == "section" and p.label is not None:
                by_label.setdefault(p.label, []).append(p.page)
        return [{"label": label, "pages": page_ranges(pages)} for label, pages in by_label.items()]

    def blank_pages(self) -> list[int]:
        return [p.page for p in self.pages if p.kind == "blank"]

    def to_dict(self) -> dict:
        return {
            "page_count": len(self.pages),
            "items": self.items,
            "sections": self.sections(),
            "blank_pages": page_ranges(self.blank_pages()),
            "warnings": self.warnings,
            "pages": [p.to_dict() for p in self.pages],
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False)

    def summary(self) -> str:
        """Résumé d'une ligne pour les logs (sans texte de page)."""
        return (
            f"{len(self.items)} items, {len(self.sections())} sections, "
            f"{len(self.blank_pages())} pages blanches, {len(self.warnings)} warnings"
        )


@dataclass
class SegmentationResult:
    items: list[DetectedItem]
    report: SegmentationReport


def segmentation_overview(raw: str | None) -> dict | None:
    """Vue du rapport stocké pour le détail de job admin : items → pages, sections, warnings
    (sans le détail page par page). None si absent (import antérieur) ou illisible."""
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except ValueError:
        logger.warning("Rapport de découpage illisible")
        return None
    if not isinstance(data, dict):
        return None
    return {key: data.get(key) for key in ("page_count", "items", "sections", "blank_pages", "warnings")}


def page_ranges(pages: list[int]) -> str:
    """[2, 3, 4, 9] → « 2-4,9 »."""
    runs: list[list[int]] = []
    for p in sorted(pages):
        if runs and p == runs[-1][1] + 1:
            runs[-1][1] = p
        else:
            runs.append([p, p])
    return ",".join(f"{a}-{b}" if a != b else str(a) for a, b in runs)


# ── R0 / R1 : fonctions pures ─────────────────────────────────────────────────


def page_lines(text: str) -> list[str]:
    """R0 : lignes utiles d'une page (dédoublées, sans filigrane ni ligne vide)."""
    lines = [undouble(line).strip() for line in text.splitlines()]
    return [line for line in lines if line and not _WATERMARK.search(line)]


def header_candidates(line: str) -> list[int]:
    """R1 : numéros candidats d'un en-tête « Item N », par ordre de préférence.

    « Item 21 2 » → [212, 21] (chiffres coupés : joint d'abord, puis 1er groupe) ;
    aucun en-tête → [].
    """
    match = _HEADER_ITEM.match(line)
    if match is None:
        return []
    groups = match.group(1).split()
    joined = int("".join(groups))
    return [joined] if len(groups) == 1 else [joined, int(groups[0])]


def _norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


# ── Analyse d'une page ────────────────────────────────────────────────────────


@dataclass
class _Page:
    idx: int
    lines: list[str]
    blank: bool
    header: list[int] = field(default_factory=list)
    objectifs: int | None = None
    strong: int | None = None
    section: str | None = None
    toc: bool = False
    signals: list[str] = field(default_factory=list)


def _table_has_rang_header(tables: PageTables) -> bool:
    return any(_RANG_TABLE.search(" ".join(str(c) for c in row if c)) for table in tables for row in table if row)


def _parse_page(idx: int, text: str, tables: PageTables) -> _Page:
    lines = page_lines(text)
    p = _Page(idx, lines, blank=len("".join(lines)) < _BLANK_MAX_CHARS)
    if p.blank:
        return p
    for line in lines[:_HEADER_LINES]:
        candidates = header_candidates(line)
        if candidates:
            p.header = candidates
            p.signals.append("en-tête:" + "/".join(str(n) for n in candidates))
            break
    m = _OBJECTIFS.search(text)
    if m:
        p.objectifs = int(m.group(1))
        p.signals.append(f"objectifs:{p.objectifs}")
    leaders = sum(1 for line in lines if _TOC_LEADER_LINE.search(line))
    toc_items = {n for n in _TOC_ITEM_LINE.findall(text)}
    p.toc = leaders >= _TOC_MIN_LEADERS or len(toc_items) >= _TOC_MIN_ITEMS
    if p.toc:
        p.signals.append("sommaire")
    # R3 : ouverture forte ; R2 prime (numéro lu en toutes lettres dans OBJECTIFS)
    if p.header and (
        _CHAPITRE.match(lines[0])
        or _CEP_FIRST_LINE.search(lines[0])
        or _RANG_TABLE.search("\n".join(lines[:_RANG_TABLE_LINES]))
        or _table_has_rang_header(tables)
    ):
        p.strong = p.header[0]
        p.signals.append(f"ouverture:{p.strong}")
    if p.objectifs is not None:
        p.strong = p.objectifs
    # R7 : sections hors item
    head = " ".join(lines[:8])
    if _CHAPITRE.match(lines[0]) and not re.search(r"\bItem\s*\d", head, re.IGNORECASE):
        title = " ".join(line for line in lines[1:4] if not line.isdigit())
        p.section = _DOSSIERS if re.search(r"dossiers? progressifs", title, re.IGNORECASE) else _CHAPTER_WITHOUT_ITEM
    else:
        for label, rx in _SECTION_PATTERNS:
            if any(rx.search(line) for line in lines[:2]):
                p.section = label
                break
    if p.toc and not p.section:
        p.section = "sommaire"
    if p.section:
        p.signals.append(f"section:{p.section}")
    return p


def _r6_toc_titles(pages: list[_Page]) -> dict[int, str]:
    """Titres du sommaire pour R6 (formats Elsevier « 7 Item 296 - Titre … 135 » et CNEC)."""
    titles: dict[int, str] = {}
    for p in pages:
        if not p.toc:
            continue
        buf: list[str] = []
        for line in p.lines:
            m = re.match(r"^(?:[\d\s]+)?Item\s*(\d{1,3})\s*[-–]\s*(.+?)(?:\s*\.{3,}.*|\s+\d+)?$", line)
            if m:
                titles.setdefault(int(m.group(1)), m.group(2))
                buf = []
                continue
            m = re.match(r"^Item\s*(\d{1,3})\b", line)
            if m and buf:
                entry = re.sub(r"^.{0,15}?\d+\s*:\s*", "", " ".join(buf))
                titles.setdefault(int(m.group(1)), re.sub(r"[.…\s\-\d]*$", "", entry))
                buf = []
                continue
            if re.search(r"[a-z]{3}", line):
                buf.append(re.sub(r"\.{3,}.*$|….*$", "", line))
                buf = buf[-3:]
    return titles


def _known_numbers(pages: list[_Page], known_titles: dict[int, str] | None) -> set[int]:
    """R4 : numéros sûrs du livre."""
    k: set[int] = set()
    for p in pages:
        if p.toc:
            k |= {int(n) for n in _TOC_ITEM_LINE.findall("\n".join(p.lines))}
        if p.objectifs is not None:
            k.add(p.objectifs)
        if p.strong is not None:
            k.add(p.strong)
    counts: dict[int, int] = {}
    for p in pages:
        if p.header and not p.toc:
            counts[p.header[0]] = counts.get(p.header[0], 0) + 1
    # En-têtes répétés, sauf préfixe tronqué d'un numéro sûr (« em 29 » ×2 alors que 298 ∈ K)
    k |= {
        n
        for n, c in counts.items()
        if c >= 2 and len(str(n)) >= 2 and not any(s != n and str(s).startswith(str(n)) for s in k)
    }
    # Référentiel partiel (quelques titres posés à la main) : il exclurait presque tout.
    if known_titles and len(known_titles) >= _COMPLETE_REFERENTIAL:
        k = {n for n in k if n in known_titles}
    return k


def _resolve(p: _Page, current: int | None, known: set[int]) -> int | None:
    """R4 : numéro désigné par l'en-tête de la page, ou None."""
    if not p.header:
        return None
    if p.header[0] in known:  # « 21 2 » → 212 si 212 est sûr
        return p.header[0]
    if current is not None and any(str(current).startswith(str(c)) for c in p.header):
        return current  # en-tête tronqué (« em 29 » dans 298, « tem 30 » dans 306)
    for candidate in p.header[1:]:
        if candidate in known:
            return candidate
    return None


# ── Rang par objectif ─────────────────────────────────────────────────────────


def _is_rang_header(line: str) -> bool:
    low = line.lower()
    k = low.find(_RUBRIQUE)
    if not 0 <= k <= _RUBRIQUE_MAX_POSITION:
        return False
    return "intitul" in low or _RANG_BEFORE_RUBRIQUE.search(low[:k]) is not None


def _glyph_counts(glyphs: list[str]) -> tuple[int, int]:
    return sum(g in _GLYPHS_A for g in glyphs), sum(g in _GLYPHS_B for g in glyphs)


def _objectives_from_text(lines: list[str], inside: bool) -> tuple[int, int, bool, bool]:
    """Objectifs A/B lus dans le tableau texte. Renvoie (a, b, tableau vu, tableau fini).

    Une ligne « <pictogramme connu> <Rubrique> … » compte même sans en-tête lu (en-tête
    perdu à l'OCR, cancéro 307) ; après l'en-tête, le tableau finit à la 1re section du cours.
    """
    glyphs: list[str] = []
    seen = False
    for line in lines:
        if _is_rang_header(line):
            inside = seen = True
            continue
        if inside and _COURSE_HEADING.match(line):
            a, b = _glyph_counts(glyphs)
            return a, b, seen, True
        m = _OBJECTIVE_ROW.match(line)
        if m and (m.group(1) in _GLYPHS_A or m.group(1) in _GLYPHS_B):
            glyphs.append(m.group(1))
            seen = True
    a, b = _glyph_counts(glyphs)
    return a, b, seen, False


def _rang_column(table: list[list[str]]) -> int | None:
    """Colonne de rang d'un tableau pdfplumber, trouvée par ses valeurs (≥ 60 % de A/B/C).

    L'en-tête « Rang » n'est pas fiable (CEP : cellules fusionnées, valeurs une colonne à gauche).
    """
    width = max((len(row) for row in table), default=0)
    for col in range(width):
        cells = [str(row[col]).strip() for row in table if col < len(row) and row[col]]
        cells = [c for c in cells if c and "rang" not in c.lower()]
        values = [c for c in cells if c.upper() in _RANG_VALUES]
        if values and len(values) >= _RANG_COLUMN_MIN_RATIO * len(cells):
            return col
    return None


def _objectives_from_tables(tables: PageTables) -> tuple[int, int, bool]:
    glyphs: list[str] = []
    found = False
    for table in tables:
        col = _rang_column(table) if table else None
        if col is None:
            continue
        found = True
        glyphs += [str(row[col]).strip().upper() for row in table if col < len(row) and row[col]]
    a, b = _glyph_counts(glyphs)
    return a, b, found


def _item_objectives(pages: list[int], parsed: list[_Page], tables: list[PageTables]) -> tuple[int, int, bool]:
    """Objectifs A/B de l'item : tableau de la page d'ouverture et des 2 suivantes.

    Par page, la source (texte ou tableaux pdfplumber) qui lit le plus d'objectifs l'emporte.
    Renvoie (a, b, tableau d'objectifs trouvé).
    """
    a = b = 0
    found = finished = False
    for idx in [p for p in pages if not parsed[p].blank][:_RANG_PAGES]:
        if finished:
            break
        ta, tb, t_seen, finished = _objectives_from_text(parsed[idx].lines, inside=found)
        pa, pb, p_seen = _objectives_from_tables(tables[idx] if idx < len(tables) else [])
        found = found or t_seen or p_seen
        if pa + pb > ta + tb:
            a, b = a + pa, b + pb
        else:
            a, b = a + ta, b + tb
    return a, b, found


# ── Titres (story 8.0) ────────────────────────────────────────────────────────


def _join_title_lines(first: str, following: list[str]) -> str:
    """Titre = première ligne + lignes de continuation (qui commencent par une minuscule)."""
    if _TABLE_HEADER_LINE.match(first):
        return ""
    parts = [first]
    for line in following:
        stripped = line.strip()
        if len(parts) >= _MAX_TITLE_LINES or not stripped or not stripped[0].islower():
            break
        parts.append(stripped)
    return clean_title(" ".join(parts))


def _titles_from_objectifs(page_texts: list[str]) -> dict[int, str]:
    titles: dict[int, str] = {}
    for text in page_texts:
        for match in _OBJECTIFS.finditer(text):
            number = int(match.group(1))
            if number in titles:
                continue
            first = match.group(2).strip()
            following = text[match.end() :].splitlines()[1:]
            if not first:
                # « OBJECTIFS: N° 304. » puis le titre seul sur la ligne suivante
                following = [line for line in following if line.strip()]
                if not following:
                    continue
                first, following = following[0].strip(), following[1:]
            title = _join_title_lines(first, following)
            if is_valid_title(title):
                titles[number] = title
    return titles


def _title_from_header(text: str, same_line_only: bool = False) -> str:
    """Titre sur la ligne « Item N – Titre » ou sur la/les ligne(s) suivante(s).

    `same_line_only` : en-tête courant, la ligne suivante est du corps de texte.
    """
    lines = [undouble(line) for line in text.splitlines()]
    non_empty = [i for i, line in enumerate(lines) if line.strip()][:_HEADER_LINES]
    found = next(((i, m) for i in non_empty if (m := _HEADER_ITEM.match(lines[i].strip()))), None)
    if found is None:
        return ""
    i, match = found
    rest = clean_title(lines[i].strip()[match.end() :])
    following = [] if same_line_only else lines[i + 1 :]
    if not rest:
        while following and not following[0].strip():
            following = following[1:]
        if not following:
            return ""
        rest, following = following[0].strip(), following[1:]
    title = _join_title_lines(rest, following)
    return title if is_valid_title(title) else ""


def _item_header_title(number: int, pages: list[int], parsed: list[_Page], page_texts: list[str]) -> str:
    """Titre lu dans l'en-tête de l'item.

    Page d'ouverture (R3) ou en-tête non répété : ligne d'en-tête ou ligne(s) suivante(s).
    En-tête courant (CNEC : « Item N » répété sur la page suivante) : la ligne suivante est du
    corps de texte ; seul un titre sur la ligne même (« Item 315 - Leucémies aiguës », en-tête
    courant Elsevier) est retenu, cherché sur les premières pages de l'item.
    """
    first = pages[0]
    nxt = parsed[first + 1] if first + 1 < len(parsed) else None
    opening = any(s.startswith("ouverture:") for s in parsed[first].signals)
    running = not opening and nxt is not None and not nxt.blank and number in nxt.header
    if not running:
        return _title_from_header(page_texts[first])
    for p in [p for p in pages if not parsed[p].blank][:_RANG_PAGES]:
        if number in parsed[p].header:
            title = _title_from_header(page_texts[p], same_line_only=True)
            if title:
                return title
    return ""


def _titles_from_toc(page_texts: list[str]) -> dict[int, str]:
    """Sommaire « Chapitre 18 : Tumeurs du pancréas ..... 307 / Item 308 » → {308: titre}."""
    titles: dict[int, str] = {}
    for text in page_texts:
        if len(set(_TOC_STRICT_ITEM.findall(text))) < _TOC_MIN_ITEMS:
            continue
        buffer: list[str] = []
        for line in text.splitlines():
            match = _TOC_TITLE_ITEM.match(line)
            if match is None:
                # Lignes de titre : ont des minuscules et au moins 3 lettres (écarte
                # « SOMMAIRE », « ► », les numéros de page seuls, les miettes OCR).
                if sum(c.isalpha() for c in line) >= 3 and any(c.islower() for c in line):
                    buffer.append(_TOC_LEADERS.sub("", line.strip()))
                continue
            number = int(match.group(1))
            entry = " ".join(buffer)
            buffer = []
            # Seules les entrées « Chapitre N : titre … Item N » sont sûres : un sommaire
            # qui met le titre sous le numéro décalerait toutes les attributions d'un rang.
            if not _TOC_CHAPTER_PREFIX.match(entry):
                continue
            title = clean_title(_TOC_CHAPTER_PREFIX.sub("", entry))
            if number not in titles and is_valid_title(title):
                titles[number] = title
    return titles


# ── Détecteur ─────────────────────────────────────────────────────────────────


class ItemDetector:
    """Découpe un collège en items (règles R0-R10) et lit le rang de leurs objectifs."""

    def detect_items(
        self,
        page_texts: list[str],
        page_scores: list[float] | None = None,
        page_tables: list[PageTables] | None = None,
        known_titles: dict[int, str] | None = None,
    ) -> SegmentationResult:
        """Découpe les pages (index = numéro de page) en items.

        Args:
            page_texts:   texte extrait par page.
            page_scores:  score de confiance par page (même longueur que page_texts).
            page_tables:  tables pdfplumber par page (list[table], table = list[row]).
            known_titles: référentiel officiel des titres (`item_titles`, source `official`) ;
                          facultatif : fournit des titres à R6 et, s'il est complet
                          (≥ 300 titres), restreint K (R4).
        """
        n_pages = len(page_texts)
        scores = page_scores if page_scores is not None else [0.9] * n_pages
        tables = page_tables if page_tables is not None else [[] for _ in page_texts]
        parsed = [_parse_page(i, text, tables[i] if i < len(tables) else []) for i, text in enumerate(page_texts)]
        known = _known_numbers(parsed, known_titles)
        r6_titles = dict(known_titles or {})
        for number, title in _r6_toc_titles(parsed).items():
            r6_titles.setdefault(number, title)
        for text in page_texts:
            for m in _OBJECTIFS.finditer(text):
                if m.group(2).strip():
                    r6_titles.setdefault(int(m.group(1)), m.group(2).strip())
        norm_titles = {n: _norm(t)[:40] for n, t in r6_titles.items() if len(_norm(t)) >= _R6_TITLE_MIN}

        report = SegmentationReport()
        assign = self._assign(parsed, known, norm_titles, report)

        items = self._build_items(page_texts, scores, tables, parsed, assign, report)
        logger.debug("Découpage : %s", report.summary())
        return SegmentationResult(items=items, report=report)

    @staticmethod
    def _assign(
        parsed: list[_Page], known: set[int], norm_titles: dict[int, str], report: SegmentationReport
    ) -> list[int | str | None]:
        """Machine à états : numéro d'item, libellé de section, ou None (page blanche)."""
        assign: list[int | str | None] = [None] * len(parsed)
        warnings = report.warnings
        current: int | None = None
        opened: set[int] = set()
        section: str | None = _FRONT_LABEL
        for i, p in enumerate(parsed):
            if p.blank:  # R9
                continue
            # R7 (R7 bis : les liminaires ne valent qu'avant le 1er item)
            if p.section and p.strong is None and not (opened and p.section in _FRONT_MATTER):
                current, section = None, p.section
                assign[i] = section
                continue
            target = p.strong  # R2, R3
            if target is None:
                n = _resolve(p, current, known)
                if n is None and p.header:
                    warnings.append(f"p{i} : en-tête {'/'.join(map(str, p.header))} ignoré (item courant {current})")
                elif n is not None and n != current:
                    confirmed = any(
                        _resolve(q, None, known) == n for q in parsed[i + 1 : i + 1 + _CONFIRM_PAGES] if q.header
                    )
                    if n in known and confirmed and n not in opened:  # R5
                        target = n
                    else:
                        warnings.append(f"p{i} : en-tête {n} ignoré (item courant {current})")
                if target is None:  # R6
                    start = _norm(" ".join(p.lines[:3]))
                    for number, title in norm_titles.items():
                        if (
                            number != current
                            and number not in opened
                            and number in known
                            and start.startswith(title[:_R6_TITLE_PREFIX])
                        ):
                            target = number
                            p.signals.append(f"titre:{number}")
                            break
            if target is not None and target != current:
                if target in opened:  # R8
                    warnings.append(f"p{i} : réouverture de l'item {target}")
                current, section = target, None
                opened.add(target)
            if current is not None:
                assign[i] = current
            else:
                assign[i] = section or _UNASSIGNED
                if section is None:
                    warnings.append(f"p{i} : page de contenu non rattachée")
        return assign

    @staticmethod
    def _build_items(
        page_texts: list[str],
        scores: list[float],
        tables: list[PageTables],
        parsed: list[_Page],
        assign: list[int | str | None],
        report: SegmentationReport,
    ) -> list[DetectedItem]:
        # Plages de pages contiguës d'un même numéro (les blanches internes restent, R9),
        # puis un item par numéro (R8 : une réouverture concatène les plages).
        pages_by_number: dict[int, list[int]] = {}
        run: tuple[int, int, int] | None = None  # (numéro, début, fin)
        runs: list[tuple[int, int, int]] = []
        for i, a in enumerate(assign):
            if isinstance(a, int):
                if run is not None and run[0] == a and all(assign[j] in (a, None) for j in range(run[2] + 1, i)):
                    run = (a, run[1], i)
                else:
                    if run is not None:
                        runs.append(run)
                    run = (a, i, i)
        if run is not None:
            runs.append(run)
        for number, start, end in runs:
            pages_by_number.setdefault(number, []).extend(range(start, end + 1))

        for i, p in enumerate(parsed):
            a = assign[i]
            if p.blank:
                report.pages.append(PageAssignment(i, "blank", signals=p.signals))
            elif isinstance(a, int):
                report.pages.append(PageAssignment(i, "item", item_number=a, signals=p.signals))
            else:
                report.pages.append(PageAssignment(i, "section", label=str(a), signals=p.signals))

        objectifs_titles = _titles_from_objectifs(page_texts)
        toc_titles = _titles_from_toc(page_texts)
        items: list[DetectedItem] = []
        for number, pages in pages_by_number.items():
            pages = sorted(set(pages))
            first = pages[0]
            objectives_a, objectives_b, table_found = _item_objectives(pages, parsed, tables)
            rang: RangType
            if objectives_a:
                rang = "A"
            elif objectives_b:
                rang = "B"
            else:
                rang = "A"
                reason = "aucun objectif A/B lu" if table_found else "sans tableau d'objectifs"
                report.warnings.append(f"item {number} : rang inconnu ({reason}), A par défaut")
            content = [p for p in pages if not parsed[p].blank]
            if len(content) < _MIN_ITEM_PAGES:
                report.warnings.append(f"item {number} : moins de 2 pages")
            title = (
                objectifs_titles.get(number)
                or toc_titles.get(number)
                or _item_header_title(number, pages, parsed, page_texts)
            )
            page_scores = [scores[p] for p in pages if p < len(scores)]
            items.append(
                DetectedItem(
                    item_number=number,
                    rang=rang,
                    chapter_title=title,
                    ocr_text="\n".join(page_texts[p] for p in pages),
                    start_page=first,
                    end_page=pages[-1],
                    ocr_confidence_score=round(sum(page_scores) / len(page_scores), 4) if page_scores else 0.0,
                    pages=pages,
                    objectives_a=objectives_a,
                    objectives_b=objectives_b,
                )
            )
            report.items.append(
                {
                    "item_number": number,
                    "pages": page_ranges(pages),
                    "page_count": len(content),
                    "rang": rang,
                    "objectives_a": objectives_a,
                    "objectives_b": objectives_b,
                }
            )
        return items
