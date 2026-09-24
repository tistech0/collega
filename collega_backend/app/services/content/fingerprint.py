"""Empreintes du stockage de contenu (chantier 1).

- Page : SHA-256 du texte brut extrait (stockage dédoublonné).
- Item : SHA-256 du texte normalisé de ses pages — décide « même contenu, on
  garde les fiches » ou « modifié, on régénère ». La normalisation ne retire que
  ce qui bouge sans que le contenu change : espaces, lignes vides, et numéros de
  page imprimés — une ligne réduite à un nombre (« 233 », « Page 12 / 436 »)
  parmi les premières ou dernières lignes d'une page (en-tête, pied de page).
  Un nombre seul dans le corps du texte (une dose dans un tableau) est gardé :
  s'il change, l'item est régénéré. Elle ne sert qu'au calcul de l'empreinte,
  jamais au texte stocké ni envoyé à Claude.
"""

import hashlib
import re

_SPACES = re.compile(r"\s+")
_PAGE_NUMBER_LINE = re.compile(r"^(page\s*)?\d+(\s*(/|sur)\s*\d+)?$", re.IGNORECASE)
# Lignes d'en-tête / de pied de page examinées à chaque extrémité d'une page.
PAGE_EDGE_LINES = 3


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def page_hash(text: str) -> str:
    return _sha256(text)


def _normalize_page(text: str) -> list[str]:
    lines = [c for c in (_SPACES.sub(" ", line).strip() for line in text.splitlines()) if c]
    edge = set(range(min(PAGE_EDGE_LINES, len(lines)))) | set(range(max(0, len(lines) - PAGE_EDGE_LINES), len(lines)))
    return [line for i, line in enumerate(lines) if not (i in edge and _PAGE_NUMBER_LINE.match(line))]


def normalize_item_pages(pages: list[str]) -> str:
    return "\n".join(line for page in pages for line in _normalize_page(page))


def item_hash(pages: list[str]) -> str:
    """Empreinte d'un item à partir du texte de chacune de ses pages."""
    return _sha256(normalize_item_pages(pages))
