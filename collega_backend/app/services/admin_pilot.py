"""Console de pilotage de la beta : accueil, pastilles du menu, fiche testeuse.

Petite échelle (quelques dizaines de testeuses) : on lit les lignes utiles et on
agrège en Python, ce qui garde les règles lisibles et testables."""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.college_catalog import college_name
from app.core.errors import not_found
from app.models.activity_day import ActivityDay
from app.models.app_setting import AppSetting
from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.item import Item
from app.models.user import User
from app.schemas.admin import (
    CollegeCostData,
    DailyActivityData,
    DailyCostData,
    UserCollegeSummary,
    UserDetailData,
    UserFeedbackData,
    UserJobSummary,
)
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
DAILY_WINDOW = 30
FEEDBACK_LIMIT = 10


def tester_status(last_seen_at: datetime | None, now: datetime, inactivity_days: int) -> str:
    if last_seen_at is None:
        return "never_seen"
    return "inactive" if now - last_seen_at > timedelta(days=inactivity_days) else "active"


STREAK_STALE_AFTER = timedelta(days=1)


def _current_streak(entry: tuple[date, int] | None, today: date) -> int:
    """La série n'est affichée que si elle porte sur hier ou aujourd'hui — une série
    vieille de plusieurs semaines (testeuse repartie) ne doit jamais s'afficher comme
    en cours."""
    if entry is None or entry[0] < today - STREAK_STALE_AFTER:
        return 0
    return entry[1]


async def pilot_settings(db: AsyncSession) -> tuple[int, str]:
    inactivity = await app_settings.get_setting(db, INACTIVITY_DAYS, DEFAULT_INACTIVITY_DAYS)
    url = await app_settings.get_setting(db, TESTFLIGHT_URL, "")
    return int(inactivity), str(url)


async def _quality_since(db: AsyncSession, now: datetime) -> datetime:
    # Lu SANS le cache 30 s de app_settings (contrairement aux autres réglages) :
    # avec plusieurs workers uvicorn, un `mark_quality_seen` sur l'un d'eux ne doit
    # pas laisser la pastille Qualité réapparaître jusqu'à 30 s sur les autres tant
    # que leur cache local n'a pas expiré.
    row = await db.get(AppSetting, QUALITY_SEEN_AT)
    raw = row.value if row is not None else None
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
            streak=_current_streak(last_streak.get(u.id), today),
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
    # Un job en échec dont le collège a été relancé (job plus récent pour le même
    # college_id) ne doit plus apparaître : la relance efface le signal d'échec
    # (spec § 2.3). Le KPI failed_imports_7d, lui, continue de compter l'échec passé.
    newer_job = aliased(GenerationJob)
    not_relaunched = ~(
        select(newer_job.id)
        .where(newer_job.college_id == GenerationJob.college_id, newer_job.created_at > GenerationJob.created_at)
        .exists()
    )
    result = await db.execute(
        select(GenerationJob, College, User.email, last_event.c.at)
        .join(College, College.id == GenerationJob.college_id)
        .outerjoin(User, User.id == GenerationJob.user_id)
        .outerjoin(last_event, last_event.c.generation_job_id == GenerationJob.id)
        .where(
            (GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
            | and_(
                GenerationJob.status == "failed",
                GenerationJob.updated_at >= now - FAILED_WINDOW,
                not_relaunched,
            )
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


async def user_detail(db: AsyncSession, user_id: uuid.UUID, now: datetime) -> UserDetailData:
    """Fiche testeuse : profil, activité des 30 derniers jours, collèges, avis."""
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")
    today = now.date()
    start = today - timedelta(days=DAILY_WINDOW - 1)
    inactivity_days, _ = await pilot_settings(db)
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)

    all_days = (
        (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user_id).order_by(ActivityDay.day)))
        .scalars()
        .all()
    )
    by_day = {d.day: d for d in all_days if d.day >= start}
    daily = []
    for i in range(DAILY_WINDOW):
        d = start + timedelta(days=i)
        row = by_day.get(d)
        daily.append(
            DailyActivityData(
                day=d.isoformat(),
                cards_reviewed=row.cards_reviewed if row else 0,
                session_completed=bool(row and row.session_completed),
            )
        )

    card_counts: dict[uuid.UUID, int] = dict(
        (
            await db.execute(
                select(FlashCard.college_id, func.count())
                .where(FlashCard.user_id == user_id)
                .group_by(FlashCard.college_id)
            )
        ).all()  # type: ignore[arg-type]
    )
    colleges = (
        (await db.execute(select(College).where(College.user_id == user_id).order_by(College.created_at.desc())))
        .scalars()
        .all()
    )
    jobs = (
        (
            await db.execute(
                select(GenerationJob).where(GenerationJob.user_id == user_id).order_by(GenerationJob.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    feedback_rows = (
        await db.execute(
            select(FlashCard, Item.item_number, College.college_ref_id)
            .join(Item, Item.id == FlashCard.item_id)
            .join(College, College.id == FlashCard.college_id)
            .where(FlashCard.user_id == user_id, FlashCard.user_feedback.is_not(None))
            .order_by(FlashCard.updated_at.desc())
            .limit(FEEDBACK_LIMIT)
        )
    ).all()

    return UserDetailData(
        user_id=str(user.id),
        email=user.email,
        first_name=user.first_name,
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
        monthly_reloads=user.monthly_reloads,
        monthly_reloads_max=monthly_reloads_max,
        monthly_reloads_reset_at=user.monthly_reloads_reset_at.isoformat() if user.monthly_reloads_reset_at else None,
        created_at=user.created_at.isoformat() if user.created_at else None,
        last_seen_at=user.last_seen_at.isoformat() if user.last_seen_at else None,
        status=tester_status(user.last_seen_at, now, inactivity_days),
        streak=_current_streak((all_days[-1].day, all_days[-1].streak), today) if all_days else 0,
        cards_30d=sum(d.cards_reviewed for d in by_day.values()),
        sessions_30d=sum(1 for d in by_day.values() if d.session_completed),
        daily=daily,
        colleges=[
            UserCollegeSummary(
                college_id=str(c.id),
                college_ref_id=c.college_ref_id,
                college_name=college_name(c.college_ref_id),
                status=c.status,
                reload_count=c.reload_count,
                reload_count_max=reload_count_max,
                card_count=card_counts.get(c.id, 0),
                progress=_progress(c),
            )
            for c in colleges
        ],
        jobs=[
            UserJobSummary(
                job_id=str(j.id),
                college_id=str(j.college_id),
                status=j.status,
                card_count=j.card_count,
                error_message=j.error_message,
                created_at=j.created_at.isoformat() if j.created_at else None,
            )
            for j in jobs
        ],
        feedback=[
            UserFeedbackData(
                card_id=str(card.id),
                college_name=college_name(ref),
                item_number=item_number,
                recto=card.recto,
                feedback=card.user_feedback or "",
                at=card.updated_at.isoformat(),
            )
            for card, item_number, ref in feedback_rows
        ],
    )


# ── Console de pilotage, task 9 — Coûts : ventilation par jour / par collège ──

COST_WINDOW_DAYS = 30


async def usage_breakdown(db: AsyncSession, now: datetime) -> tuple[list[DailyCostData], list[CollegeCostData], float]:
    """Coût par jour et par collège sur 30 jours ; coût moyen de génération d'un import terminé."""
    first_day = now.date() - timedelta(days=COST_WINDOW_DAYS - 1)
    start = datetime.combine(first_day, time.min, tzinfo=UTC)
    sums = (func.sum(ClaudeUsage.input_tokens), func.sum(ClaudeUsage.output_tokens))

    day_col = func.date(ClaudeUsage.created_at)
    per_day: dict[date, UsageTotals] = defaultdict(UsageTotals)
    for day, model, u_in, u_out in (
        await db.execute(
            select(day_col, ClaudeUsage.model, *sums)
            .where(ClaudeUsage.created_at >= start)
            .group_by(day_col, ClaudeUsage.model)
        )
    ).all():
        per_day[day].add(model, u_in or 0, u_out or 0)
    daily = []
    for i in range(COST_WINDOW_DAYS):
        day = first_day + timedelta(days=i)
        daily.append(DailyCostData(day=day.isoformat(), cost_eur=per_day[day].cost_eur if day in per_day else 0.0))

    per_college: dict[tuple[uuid.UUID | None, int | None], UsageTotals] = defaultdict(UsageTotals)
    for college_id, ref_id, model, u_in, u_out in (
        await db.execute(
            select(ClaudeUsage.college_id, College.college_ref_id, ClaudeUsage.model, *sums)
            .outerjoin(College, College.id == ClaudeUsage.college_id)
            .where(ClaudeUsage.created_at >= now - timedelta(days=COST_WINDOW_DAYS))
            .group_by(ClaudeUsage.college_id, College.college_ref_id, ClaudeUsage.model)
        )
    ).all():
        per_college[(college_id, ref_id)].add(model, u_in or 0, u_out or 0)
    by_college = sorted(
        (
            CollegeCostData(
                college_id=str(cid) if cid else None,
                college_name=college_name(ref) if ref is not None else "Collège supprimé",
                cost_eur=t.cost_eur,
            )
            for (cid, ref), t in per_college.items()
        ),
        key=lambda c: c.cost_eur,
        reverse=True,
    )

    per_job: dict[uuid.UUID, UsageTotals] = defaultdict(UsageTotals)
    for job_id, model, u_in, u_out in (
        await db.execute(
            select(ClaudeUsage.job_id, ClaudeUsage.model, *sums)
            .join(GenerationJob, GenerationJob.id == ClaudeUsage.job_id)
            .where(ClaudeUsage.kind == "generation", GenerationJob.status == "generation_complete")
            .group_by(ClaudeUsage.job_id, ClaudeUsage.model)
        )
    ).all():
        per_job[job_id].add(model, u_in or 0, u_out or 0)
    avg = round(sum(t.cost_eur for t in per_job.values()) / len(per_job), 4) if per_job else 0.0
    return daily, by_college, avg
