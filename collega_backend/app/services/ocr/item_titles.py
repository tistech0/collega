"""Titres d'items ECN : nettoyage, filtre de validité et référentiel partagé (story 8.0).

Les items de l'ECN sont universels : un titre bien extrait d'un collège sert à tous
les autres. Les titres valides alimentent la table `item_titles` ; un item sans titre
exploitable est complété par correspondance de numéro.
"""
from __future__ import annotations

import re

from sqlalchemy import case, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.item import Item
from app.models.item_title import ItemTitle

MAX_TITLE_LENGTH = 200
_MIN_TITLE_LENGTH = 5
_MIN_SINGLE_WORD_LETTERS = 6
_MIN_LETTER_RATIO = 0.6

_LEADING_NOISE = re.compile(r"^[\s\-–—:.,;]+")
_TRAILING_NOISE = re.compile(r"[\s.,;:\-–—]+$")
_DOT_LEADERS = re.compile(r"\.{4,}|(?:\.\s){3,}")
_BULLETS = re.compile(r"[•►➔◄▪■●]")
_AUTHOR = re.compile(r"\b(?:Pr|Dr)\.?\s+[A-ZÀ-ÖØ-Þ]")
_META = re.compile(r"objectif|\brang\s+[ABC]\b|^rang\b|\brubrique\b", re.IGNORECASE)
# Intertitres de section du corps d'un chapitre : jamais un intitulé d'item à eux seuls
_SECTION_HEADINGS = frozenset(
    "introduction épidémiologie epidemiologie généralités generalites physiopathologie "
    "diagnostic définition definition définitions traitement traitements clinique sommaire "
    "étiologies etiologies conclusion prévention prevention pronostic".split()
)
_MIN_LONGEST_WORD = 4
# Mots qu'une troncature à 200 caractères ne doit pas laisser pendre en fin de titre
_DANGLING_WORDS = frozenset(
    "et ou de du des la le les à au aux en d' l' dont par pour sur avec dans un une".split()
)


def clean_title(raw: str) -> str:
    """Normalise un titre brut : espaces, séparateurs en tête, ponctuation finale, 200 car. max."""
    title = " ".join(raw.split())
    title = _LEADING_NOISE.sub("", title)
    title = _TRAILING_NOISE.sub("", title)
    letters = [c for c in title if c.isalpha()]
    if len(letters) >= _MIN_LONGEST_WORD and all(c.isupper() for c in letters):
        # « TOUX CHEZ L’ADULTE » → « Toux chez l’adulte »
        title = title[0] + title[1:].lower()
    if len(title) > MAX_TITLE_LENGTH:
        cut = title[: MAX_TITLE_LENGTH + 1].rfind(" ")
        words = title[: cut if cut > 0 else MAX_TITLE_LENGTH].split()
        while len(words) > 1 and words[-1].lower() in _DANGLING_WORDS:
            words.pop()
        title = _TRAILING_NOISE.sub("", " ".join(words))
    return title


def is_valid_title(title: str) -> bool:
    """Vrai si le titre ressemble à un intitulé d'item (et pas à du corps de texte)."""
    if not (_MIN_TITLE_LENGTH <= len(title) <= MAX_TITLE_LENGTH):
        return False
    if not title[0].isupper():
        return False
    if _DOT_LEADERS.search(title) or _BULLETS.search(title):
        return False
    if _AUTHOR.search(title) or _META.search(title):
        return False
    if title.lower() in _SECTION_HEADINGS:
        return False
    visible = [c for c in title if not c.isspace()]
    letters = sum(1 for c in visible if c.isalpha())
    if letters / len(visible) < _MIN_LETTER_RATIO:
        return False
    words = title.split()
    if len(words) == 1 and letters < _MIN_SINGLE_WORD_LETTERS:
        return False
    longest = max(sum(1 for c in w if c.isalpha()) for w in words)
    return longest >= _MIN_LONGEST_WORD


async def lookup_title(db: AsyncSession, item_number: int) -> str | None:
    """Libellé retenu pour un numéro : `official` d'abord, puis le plus fréquent, puis le plus ancien."""
    result = await db.execute(
        select(ItemTitle.label)
        .where(ItemTitle.item_number == item_number)
        .order_by(
            case((ItemTitle.source == "official", 0), else_=1),
            ItemTitle.occurrences.desc(),
            ItemTitle.id.asc(),
        )
        .limit(1)
    )
    return result.scalar_one_or_none()


async def record_title(db: AsyncSession, item_number: int, raw_title: str) -> bool:
    """Enregistre un titre extrait dans le référentiel et complète les items sans titre.

    Retourne False (sans rien écrire) si le titre ne passe pas le filtre de validité.
    """
    label = clean_title(raw_title)
    if not is_valid_title(label):
        return False

    # Tout en savepoints : une erreur ici (conflit, SQL) ne doit jamais laisser la
    # transaction de l'import en échec. Deux imports concurrents peuvent insérer le même
    # couple (numéro, libellé) : le perdant retombe sur l'incrément.
    async with db.begin_nested():
        try:
            async with db.begin_nested():
                db.add(
                    ItemTitle(item_number=item_number, label=label, source="extracted", occurrences=1)
                )
        except IntegrityError:
            await db.execute(
                update(ItemTitle)
                .where(ItemTitle.item_number == item_number, ItemTitle.label == label)
                .values(occurrences=ItemTitle.occurrences + 1)
                .execution_options(synchronize_session=False)
            )
        await backfill_untitled_items(db, item_number)
    return True


async def ensure_title(db: AsyncSession, item_number: int, raw_title: str) -> bool:
    """Comme `record_title`, sans compter une occurrence si le libellé est déjà connu.

    Pour les rattrapages rejouables (script de backfill) : relancer ne doit pas
    fausser la priorité « libellé le plus fréquent ».
    """
    label = clean_title(raw_title)
    if not is_valid_title(label):
        return False
    async with db.begin_nested():
        known = (
            await db.execute(
                select(ItemTitle.id).where(
                    ItemTitle.item_number == item_number, ItemTitle.label == label
                )
            )
        ).first()
        if known is None:
            db.add(ItemTitle(item_number=item_number, label=label, source="extracted", occurrences=1))
            await db.flush()
        await backfill_untitled_items(db, item_number)
    return True


async def backfill_untitled_items(db: AsyncSession, item_number: int) -> None:
    """Donne le libellé du référentiel aux items de ce numéro dont le titre est nul ou vide."""
    best = await lookup_title(db, item_number)
    if best is None:
        return
    await db.execute(
        update(Item)
        .where(Item.item_number == item_number)
        .where(or_(Item.chapter_title.is_(None), Item.chapter_title == ""))
        .values(chapter_title=best)
        .execution_options(synchronize_session=False)
    )


async def record_official_title(db: AsyncSession, item_number: int, raw_title: str) -> None:
    """Inscrit un libellé `official` (prioritaire) et l'applique aux items de ce numéro.

    Remplace aussi le titre des items qui tenaient un libellé extrait de ce numéro :
    l'officiel sert précisément à corriger une extraction ratée (lettrine, OCR).
    """
    label = clean_title(raw_title)
    if not is_valid_title(label):
        raise ValueError(f"Titre invalide pour l'item {item_number} : {raw_title!r}")

    existing = (
        await db.execute(
            select(ItemTitle).where(ItemTitle.item_number == item_number, ItemTitle.label == label)
        )
    ).scalar_one_or_none()
    if existing is None:
        db.add(ItemTitle(item_number=item_number, label=label, source="official", occurrences=1))
    else:
        existing.source = "official"
    await db.flush()

    extracted_labels = select(ItemTitle.label).where(
        ItemTitle.item_number == item_number, ItemTitle.source == "extracted"
    )
    await db.execute(
        update(Item)
        .where(Item.item_number == item_number)
        .where(
            or_(
                Item.chapter_title.is_(None),
                Item.chapter_title == "",
                Item.chapter_title.in_(extracted_labels),
            )
        )
        .values(chapter_title=label)
        .execution_options(synchronize_session=False)
    )
