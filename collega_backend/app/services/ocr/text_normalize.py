"""Normalisation pure du texte extrait des PDF (partagée par l'extraction, le découpage
et l'allègement du texte envoyé à Claude)."""

from __future__ import annotations

import re

# Motifs de filigrane relevés en prod (spec chantier 4 § 5), insensibles à la casse :
# « Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com… »,
# « Il a été diffusé exclusivement et gratuitement sur le forum © SBA-MEDECINE »,
# « pour plus des livres médicaux gratuits… www.sba-medecin… », « Faille_V2 ».
WATERMARK_PATTERN = re.compile(
    r"Pour avoir plus d.exclusivit|amis-med\.com|Faille_V2|livres m.dicaux gratuits|sba-m.decine"
    r"|diffus. exclusivement",
    re.IGNORECASE,
)

# Part minimale de paires identiques pour considérer une ligne comme doublée
_DOUBLED_PAIRS_RATIO = 0.8
_MIN_LENGTH = 6


def undouble(line: str) -> str:
    """« TTuummeeuurrss » → « Tumeurs » quand la ligne est faite de lettres doublées.

    Certains PDF scannés ont des glyphes réellement doublés dans leur couche OCR
    (titres de chapitres, pages liminaires) que `dedupe_chars()` ne retire pas.
    Une ligne est dédoublée si ≥ 80 % de ses paires (0-1, 2-3…) sont identiques.
    Les lignes sans lettre (points de conduite d'un sommaire) restent intactes,
    ce qui rend la fonction idempotente sur les lignes déjà dédoublées.
    """
    s = line.strip()
    if len(s) < _MIN_LENGTH or not any(c.isalpha() for c in s):
        return line
    pairs = sum(1 for i in range(0, len(s) - 1, 2) if s[i] == s[i + 1])
    if pairs >= _DOUBLED_PAIRS_RATIO * (len(s) // 2):
        return s[::2]
    return line


def undouble_text(text: str) -> str:
    """Applique `undouble` à chaque ligne d'un texte."""
    return "\n".join(undouble(line) for line in text.split("\n"))
