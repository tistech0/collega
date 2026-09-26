"""Console de pilotage de la beta : accueil, pastilles du menu, fiche testeuse.

Petite échelle (quelques dizaines de testeuses) : on lit les lignes utiles et on
agrège en Python, ce qui garde les règles lisibles et testables."""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.college_catalog import college_name
from app.models.activity_day import ActivityDay
from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.user import User
from app.schemas.admin_pilot import (
    AdminCollegeRow,
    BadgesData,
    Kpi,
    PilotData,
    RunningJob,
    TesterRow,
    WatchFeedback,
    WatchJob,
)
from app.services import app_settings
from app.services.generation.token_cost import UsageTotals

INACTIVITY_DAYS = "inactivity_days"
QUALITY_SEEN_AT = "quality_seen_at"
TESTFLIGHT_URL = "testflight_url"
DEFAULT_INACTIVITY_DAYS = 5
ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")
STALL_AFTER = timedelta(minutes=15)
FAILED_WINDOW = timedelta(days=7)
QUALITY_DEFAULT_WINDOW = timedelta(days=7)


def tester_status(last_seen_at: datetime | None, now: datetime, inactivity_days: int) -> str:
    if last_seen_at is None:
        return "never_seen"
    return "inactive" if now - last_seen_at > timedelta(days=inactivity_days) else "active"


async def pilot_settings(db: AsyncSession) -> tuple[int, str]:
    inactivity = await app_settings.get_setting(db, INACTIVITY_DAYS, DEFAULT_INACTIVITY_DAYS)
    url = await app_settings.get_setting(db, TESTFLIGHT_URL, "")
    return int(inactivity), str(url)


async def _quality_since(db: AsyncSession, now: datetime) -> datetime:
    raw = await app_settings.get_setting(db, QUALITY_SEEN_AT, None)
    return datetime.fromisoformat(raw) if raw else now - QUALITY_DEFAULT_WINDOW


async def mark_quality_seen(db: AsyncSession, now: datetime) -> None:
    await app_settings.set_setting(db, QUALITY_SEEN_AT, now.isoformat())
    await db.commit()


async def _activity_rows(db: AsyncSession, since: date) -> list[ActivityDay]:
    return list((await db.execute(select(ActivityDay).where(ActivityDay.day >= since))).scalars().all())


async def tester_rows(db: AsyncSession, now: datetime, today: date) -> list[TesterRow]:
    inactivity_days, _ = await pilot_settings(db)
    users = (await db.execute(select(User).order_by(User.created_at.desc()))).scalars().all()
    college_counts: dict[uuid.UUID, int] = dict(
        (await db.execute(select(College.user_id, func.count()).group_by(College.user_id))).all()  # type: ignore[arg-type]
    )
    rows = await _activity_rows(db, today - timedelta(days=60))
    last_streak: dict[uuid.UUID, tuple[date, int]] = {}
    cards_7d: dict[uuid.UUID, int] = defaultdict(int)
    for r in rows:
        if r.user_id not in last_streak or r.day > last_streak[r.user_id][0]:
            last_streak[r.user_id] = (r.day, r.streak)
        if r.day > today - timedelta(days=7):
            cards_7d[r.user_id] += r.cards_reviewed
    return [
        TesterRow(
            user_id=str(u.id),
            email=u.email,
            first_name=u.first_name,
            is_beta=u.is_beta,
            created_at=u.created_at.isoformat(),
            last_seen_at=u.last_seen_at.isoformat() if u.last_seen_at else None,
            status=tester_status(u.last_seen_at, now, inactivity_days),
            streak=last_streak.get(u.id, (today, 0))[1],
            cards_7d=cards_7d.get(u.id, 0),
            college_count=college_counts.get(u.id, 0),
        )
        for u in users
    ]


async def _jobs_to_watch(db: AsyncSession, now: datetime) -> tuple[list[WatchJob], list[RunningJob]]:
    last_event = (
        select(GenerationJobEvent.generation_job_id, func.max(GenerationJobEvent.created_at).label("at"))
        .group_by(GenerationJobEvent.generation_job_id)
        .subquery()
    )
    result = await db.execute(
        select(GenerationJob, College, User.email, last_event.c.at)
        .join(College, College.id == GenerationJob.college_id)
        .outerjoin(User, User.id == GenerationJob.user_id)
        .outerjoin(last_event, last_event.c.generation_job_id == GenerationJob.id)
        .where(
            (GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
            | and_(GenerationJob.status == "failed", GenerationJob.updated_at >= now - FAILED_WINDOW)
        )
        .order_by(GenerationJob.updated_at.desc())
    )
    watch: list[WatchJob] = []
    running: list[RunningJob] = []
    for job, college, email, event_at in result.all():
        name = college_name(college.college_ref_id)
        if job.status == "failed":
            watch.append(_watch(job, college, name, email, "failed"))
            continue
        # Dernier signe de vie : le dernier événement du job (le worker en émet pendant
        # l'OCR et la génération), à défaut sa dernière mise à jour.
        last_activity = event_at or job.updated_at
        if now - last_activity > STALL_AFTER:
            watch.append(_watch(job, college, name, email, "stalled"))
        else:
            running.append(
                RunningJob(
                    job_id=str(job.id),
                    college_name=name,
                    user_email=email,
                    status=job.status,
                    progress=_progress(college),
                )
            )
    return watch, running


def _watch(job: GenerationJob, college: College, name: str, email: str | None, kind: str) -> WatchJob:
    return WatchJob(
        job_id=str(job.id),
        college_id=str(college.id),
        college_name=name,
        user_email=email,
        status=job.status,
        kind=kind,
        message=job.error_message,
        updated_at=job.updated_at.isoformat(),
    )


def _progress(college: College) -> float:
    """OCR = première moitié, génération = seconde moitié (comme l'écran d'import de l'app)."""
    ocr = college.ocr_page_progress / college.total_pages if college.total_pages else 0.0
    gen = college.generation_items_done / college.generation_items_total if college.generation_items_total else 0.0
    return round(min(1.0, 0.5 * ocr + 0.5 * gen), 3)


async def _negative_feedback(db: AsyncSession, since: datetime) -> list[WatchFeedback]:
    result = await db.execute(
        select(College.id, College.college_ref_id, func.count())
        .join(FlashCard, FlashCard.college_id == College.id)
        .where(FlashCard.user_feedback == "negative", FlashCard.updated_at > since)
        .group_by(College.id, College.college_ref_id)
    )
    return [
        WatchFeedback(college_id=str(cid), college_name=college_name(ref), negative_count=count)
        for cid, ref, count in result.all()
    ]


async def _cost(db: AsyncSession, start: datetime, end: datetime) -> float:
    totals = UsageTotals()
    result = await db.execute(
        select(ClaudeUsage.model, func.sum(ClaudeUsage.input_tokens), func.sum(ClaudeUsage.output_tokens))
        .where(ClaudeUsage.created_at >= start, ClaudeUsage.created_at < end)
        .group_by(ClaudeUsage.model)
    )
    for model, u_in, u_out in result.all():
        totals.add(model, u_in or 0, u_out or 0)
    return totals.cost_eur


async def _failed_count(db: AsyncSession, start: datetime, end: datetime) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(GenerationJob)
        .where(GenerationJob.status == "failed", GenerationJob.updated_at >= start, GenerationJob.updated_at < end)
    )
    return int(result.scalar_one())


async def pilot(db: AsyncSession, now: datetime) -> PilotData:
    today = now.date()
    testers = await tester_rows(db, now, today)
    # Les KPI (actives, fiches) ne portent que sur les comptes beta — les comptes
    # de test/admin ont aussi des ActivityDay mais ne doivent ni gonfler « fiches
    # révisées » ni permettre à « actives » de dépasser `testers_total` (beta seul).
    beta_ids = {uuid.UUID(t.user_id) for t in testers if t.is_beta}
    rows = [r for r in await _activity_rows(db, today - timedelta(days=13)) if r.user_id in beta_ids]
    week, prev_week = today - timedelta(days=6), today - timedelta(days=13)

    def period(start: date, end: date) -> list[ActivityDay]:
        return [r for r in rows if start <= r.day <= end]

    current, previous = period(week, today), period(prev_week, week - timedelta(days=1))
    watch, running = await _jobs_to_watch(db, now)
    return PilotData(
        testers_total=sum(1 for t in testers if t.is_beta),
        active_7d=Kpi(
            value=len({r.user_id for r in current if r.cards_reviewed > 0}),
            previous=len({r.user_id for r in previous if r.cards_reviewed > 0}),
        ),
        cards_7d=Kpi(value=sum(r.cards_reviewed for r in current), previous=sum(r.cards_reviewed for r in previous)),
        failed_imports_7d=Kpi(
            value=await _failed_count(db, now - FAILED_WINDOW, now),
            previous=await _failed_count(db, now - 2 * FAILED_WINDOW, now - FAILED_WINDOW),
        ),
        cost_30d_eur=Kpi(
            value=await _cost(db, now - timedelta(days=30), now),
            previous=await _cost(db, now - timedelta(days=60), now - timedelta(days=30)),
        ),
        testers=[t for t in testers if t.is_beta],
        watch_jobs=watch,
        watch_feedback=await _negative_feedback(db, await _quality_since(db, now)),
        running_jobs=running,
    )


async def badges(db: AsyncSession, now: datetime) -> BadgesData:
    testers = await tester_rows(db, now, now.date())
    watch, _ = await _jobs_to_watch(db, now)
    feedback = await _negative_feedback(db, await _quality_since(db, now))
    return BadgesData(
        testers=sum(1 for t in testers if t.is_beta and t.status != "active"),
        imports=len(watch),
        quality=sum(f.negative_count for f in feedback),
    )


async def list_colleges(db: AsyncSession) -> list[AdminCollegeRow]:
    cards = (
        select(
            FlashCard.college_id,
            func.count().label("cards"),
            func.count().filter(FlashCard.user_feedback == "negative").label("negative"),
        )
        .group_by(FlashCard.college_id)
        .subquery()
    )
    result = await db.execute(
        select(College, User.email, cards.c.cards, cards.c.negative)
        .outerjoin(User, User.id == College.user_id)
        .outerjoin(cards, cards.c.college_id == College.id)
        .order_by(College.created_at.desc())
    )
    return [
        AdminCollegeRow(
            college_id=str(c.id),
            college_ref_id=c.college_ref_id,
            college_name=college_name(c.college_ref_id),
            user_email=email,
            status=c.status,
            card_count=n_cards or 0,
            negative_count=n_negative or 0,
            created_at=c.created_at.isoformat(),
        )
        for c, email, n_cards, n_negative in result.all()
    ]
