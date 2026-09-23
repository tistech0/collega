"""Empreintes du stockage de contenu (chantier 1).

- Page : SHA-256 du texte brut extrait (stockage dédoublonné).
- Item : SHA-256 du texte normalisé — décide « même contenu, on garde les
  fiches » ou « modifié, on régénère ». La normalisation retire ce qui bouge
  sans que le contenu change (numéros de page imprimés, espaces) ; elle ne sert
  qu'au calcul de l'empreinte, jamais au texte stocké ni envoyé à Claude.
"""
import hashlib
import re

_SPACES = re.compile(r"\s+")
_PAGE_NUMBER_LINE = re.compile(r"^(page\s*)?\d+(\s*(/|sur)\s*\d+)?$", re.IGNORECASE)


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def page_hash(text: str) -> str:
    return _sha256(text)


def normalize_item_text(text: str) -> str:
    lines = []
    for line in text.splitlines():
        compact = _SPACES.sub(" ", line).strip()
        if not compact or _PAGE_NUMBER_LINE.match(compact):
            continue
        lines.append(compact)
    return "\n".join(lines)


def item_hash(text: str) -> str:
    return _sha256(normalize_item_text(text))
