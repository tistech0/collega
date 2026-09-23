"""Fabriques de données pour les tests sur Postgres réel (chantier 1)."""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.college import College, CollegeStatus
from app.models.content import JobItem, JobPage
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.item import Item
from app.models.user import User
from app.services.content import store


async def make_user(db: AsyncSession, *, apns_token: str | None = "tok", monthly_reloads: int = 0) -> User:
    user = User(
        id=uuid.uuid4(),
        email=f"{uuid.uuid4().hex[:10]}@test.fr",
        hashed_password="x",
        is_subscribed=True,
        apns_token=apns_token,
        monthly_reloads=monthly_reloads,
    )
    db.add(user)
    await db.flush()
    return user


async def make_college(
    db: AsyncSession, user: User, *, status: str = CollegeStatus.pending, ref_id: int = 34, reload_count: int = 0
) -> College:
    college = College(
        id=uuid.uuid4(), user_id=user.id, college_ref_id=ref_id, status=status, reload_count=reload_count
    )
    db.add(college)
    await db.flush()
    return college


async def make_job(db: AsyncSession, college: College, *, status: str = "pending") -> GenerationJob:
    job = GenerationJob(id=uuid.uuid4(), college_id=college.id, user_id=college.user_id, status=status)
    db.add(job)
    await db.flush()
    return job


async def make_item(
    db: AsyncSession, college: College, number: int, *, text: str | None = None, rang: str = "A"
) -> Item:
    text_hash = await store.put_item_text(db, text) if text is not None else None
    item = Item(
        id=uuid.uuid4(), college_id=college.id, item_number=number, rang=rang,
        chapter_title=f"Item {number}", text_hash=text_hash, ocr_confidence_score=0.9,
        low_confidence=False, start_page=0, end_page=1,
    )
    db.add(item)
    await db.flush()
    return item


async def make_card(db: AsyncSession, item: Item, *, recto: str = "Q ?", verso: str = "R", **kw) -> FlashCard:
    college = await db.get(College, item.college_id)
    card = FlashCard(
        id=uuid.uuid4(), item_id=item.id, college_id=item.college_id, user_id=college.user_id,
        card_type=kw.pop("card_type", "classique"), rang=item.rang, recto=recto, verso=verso, **kw,
    )
    db.add(card)
    await db.flush()
    return card


async def make_draft(
    db: AsyncSession, job: GenerationJob, number: int, text: str, cards: list[dict] | None = None,
    *, version: str = "claude-sonnet-4-6:p1", rang: str = "A",
) -> JobItem:
    """Item détecté par l'import `job` ; `cards` non None → génération d'origine déjà faite."""
    text_hash = await store.put_item_text(db, text)
    generation_id = None
    if cards is not None:
        gen = await store.put_generation(db, text_hash, version, cards, "claude-sonnet-4-6", 10, 5)
        generation_id = gen.id
    draft = JobItem(
        job_id=job.id, item_number=number, rang=rang, chapter_title=f"Item {number}", start_page=0,
        end_page=1, ocr_confidence_score=0.9, low_confidence=False, text_hash=text_hash,
        generation_id=generation_id,
    )
    db.add(draft)
    await db.flush()
    return draft


async def make_job_page(db: AsyncSession, job: GenerationJob, number: int, text: str) -> JobPage:
    h = await store.put_page(db, text, [], 0.9, "pdfplumber")
    page = JobPage(job_id=job.id, page_number=number, page_hash=h)
    db.add(page)
    await db.flush()
    return page


def cards(*rectos: str) -> list[dict]:
    return [{"card_type": "classique", "recto": r, "verso": f"réponse {r}"} for r in rectos]


def write_pdf(storage: Path, college: College, job: GenerationJob) -> Path:
    path = storage / f"{college.id}_{job.id}.pdf"
    path.write_bytes(b"%PDF-1.4\n%%EOF\n")
    return path


@dataclass
class Seed:
    user: User
    college: College
    job: GenerationJob
    pdf_path: Path
