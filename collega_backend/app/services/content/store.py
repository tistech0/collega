"""Accès aux tables de contenu adressées par empreinte (chantier 1).

Écritures en INSERT … ON CONFLICT DO NOTHING : deux imports concurrents (même
PDF chez deux utilisatrices) peuvent écrire la même empreinte sans erreur.
"""

import json
import uuid
from typing import Any

from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import ItemGeneration, ItemText, OcrPage
from app.services.content.fingerprint import item_hash, page_hash

# Verrou consultatif Postgres (clé arbitraire, propre à ce stockage) : les écritures
# des imports le prennent en PARTAGÉ jusqu'à la fin de leur transaction, la purge en
# EXCLUSIF. Sans lui, la purge pourrait supprimer une page ou un texte qu'un import
# concurrent (même PDF) vient de « retrouver » par ON CONFLICT DO NOTHING et va
# référencer — son insertion suivante violerait alors la clé étrangère.
CONTENT_LOCK_KEY = 0x636F6C6C  # « coll »


async def hold_content_lock_shared(db: AsyncSession) -> None:
    await db.execute(text("SELECT pg_advisory_xact_lock_shared(:k)"), {"k": CONTENT_LOCK_KEY})


async def hold_content_lock_exclusive(db: AsyncSession) -> None:
    await db.execute(text("SELECT pg_advisory_xact_lock(:k)"), {"k": CONTENT_LOCK_KEY})


async def put_page(db: AsyncSession, text: str, tables: list, confidence: float, method: str) -> str:
    h = page_hash(text)
    await hold_content_lock_shared(db)
    await db.execute(
        insert(OcrPage)
        .values(
            hash=h, text=text, tables_json=json.dumps(tables, ensure_ascii=False), confidence=confidence, method=method
        )
        .on_conflict_do_nothing(index_elements=["hash"])
    )
    return h


async def load_pages(db: AsyncSession, hashes: list[str]) -> dict[str, OcrPage]:
    if not hashes:
        return {}
    rows = await db.execute(select(OcrPage).where(OcrPage.hash.in_(set(hashes))))
    return {p.hash: p for p in rows.scalars()}


# Séparateur de pages dans `item_texts.text` (chantier 4) : la génération redécoupe
# l'item en pages pour `clean_for_prompt` (en-têtes répétés d'une page à l'autre). Un
# « \f » présent dans le texte d'une page y devient un retour à la ligne. Les textes
# antérieurs, sans séparateur, se relisent comme une seule page.
PAGE_SEPARATOR = "\f"


async def put_item_text(db: AsyncSession, pages: list[str]) -> str:
    """Stocke le texte d'un item (ses pages, séparées par PAGE_SEPARATOR) sous
    l'empreinte normalisée calculée page par page (sur les pages d'origine)."""
    h = item_hash(pages)
    text = PAGE_SEPARATOR.join(p.replace(PAGE_SEPARATOR, "\n") for p in pages)
    await hold_content_lock_shared(db)
    await db.execute(insert(ItemText).values(hash=h, text=text).on_conflict_do_nothing(index_elements=["hash"]))
    return h


async def get_item_pages(db: AsyncSession, text_hash: str) -> list[str] | None:
    """Les pages de l'item, telles que stockées (génération)."""
    row = await db.get(ItemText, text_hash)
    return row.text.split(PAGE_SEPARATOR) if row else None


async def get_item_text(db: AsyncSession, text_hash: str) -> str | None:
    """Le texte de l'item d'un seul tenant, pages jointes par des retours à la ligne
    (affichage). La régénération d'une fiche lit les pages (`get_item_pages`)."""
    row = await db.get(ItemText, text_hash)
    return row.text.replace(PAGE_SEPARATOR, "\n") if row else None


async def find_generation(db: AsyncSession, text_hash: str, version: str) -> ItemGeneration | None:
    rows = await db.execute(
        select(ItemGeneration)
        .where(ItemGeneration.text_hash == text_hash)
        .where(ItemGeneration.generation_version == version)
    )
    return rows.scalar_one_or_none()


async def put_generation(
    db: AsyncSession,
    text_hash: str,
    version: str,
    cards: list[dict[str, Any]],
    model: str,
    input_tokens: int,
    output_tokens: int,
    *,
    insufficient_text: bool = False,
) -> ItemGeneration:
    """Enregistre la sortie d'origine de Claude ; si une génération existe déjà pour
    (empreinte, version) — import concurrent —, c'est elle qui est renvoyée.
    `insufficient_text` : texte jugé sans contenu d'enseignement (0 fiche)."""
    await hold_content_lock_shared(db)
    await db.execute(
        insert(ItemGeneration)
        .values(
            id=uuid.uuid4(),
            text_hash=text_hash,
            generation_version=version,
            cards_json=json.dumps(cards, ensure_ascii=False),
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            insufficient_text=insufficient_text,
        )
        .on_conflict_do_nothing(constraint="uq_item_generations_hash_version")
    )
    gen = await find_generation(db, text_hash, version)
    if gen is None:  # pragma: no cover — impossible après l'INSERT ci-dessus
        raise RuntimeError(f"item_generation introuvable après insertion ({text_hash}, {version})")
    return gen


def generation_cards(gen: ItemGeneration) -> list[dict[str, Any]]:
    return json.loads(gen.cards_json)
