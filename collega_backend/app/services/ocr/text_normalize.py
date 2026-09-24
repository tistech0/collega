"""Normalisation pure du texte extrait des PDF (partagée par l'extraction et le découpage)."""

from __future__ import annotations

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
