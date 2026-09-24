"""Routes admin — utilisateurs : liste, création, bêta, reset du quota, mot de passe, détail.

Toutes les routes sont protégées par HTTP Basic Auth.
"""

from __future__ import annotations

import secrets
import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.errors import conflict, not_found
from app.core.security import hash_password
from app.deps import get_admin_user
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.schemas.admin import (
    BetaUpdateRequest,
    BetaUpdateResponseWrapped,
    CreateUserRequest,
    CreateUserResponseWrapped,
    ResetPasswordData,
    ResetPasswordResponseWrapped,
    ResetQuotaResponseWrapped,
    UserBetaData,
    UserCollegeSummary,
    UserDetailData,
    UserDetailResponseWrapped,
    UserJobSummary,
    UsersListResponseWrapped,
)
from app.services import app_settings

router = APIRouter()


# ── Story 1.4 — Gestion utilisateurs beta ────────────────────────────────────


@router.get("/users", response_model=UsersListResponseWrapped)
async def list_users(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UsersListResponseWrapped:
    """Liste tous les utilisateurs avec leur statut beta et abonnement."""
    result = await db.execute(select(User).order_by(User.created_at.desc()))
    users = result.scalars().all()
    _, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    user_data = [
        UserBetaData(
            user_id=str(u.id),
            email=u.email,
            is_beta=u.is_beta,
            is_subscribed=u.is_subscribed,
            monthly_reloads=u.monthly_reloads,
            monthly_reloads_max=monthly_reloads_max,
        )
        for u in users
    ]
    return UsersListResponseWrapped(data=user_data, total=len(user_data))


@router.patch("/users/{user_id}/beta", response_model=BetaUpdateResponseWrapped)
async def update_user_beta(
    user_id: uuid.UUID,
    body: BetaUpdateRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> BetaUpdateResponseWrapped:
    """Active ou désactive le flag is_beta pour un utilisateur."""
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")
    user.is_beta = body.is_beta
    await db.commit()
    _, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return BetaUpdateResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=user.monthly_reloads,
            monthly_reloads_max=monthly_reloads_max,
        )
    )


# ── Story 7.6 — Création utilisateur admin (hard-blocker onboarding) ──────────


@router.post("/users", response_model=CreateUserResponseWrapped, status_code=201)
async def create_user(
    body: CreateUserRequest,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> CreateUserResponseWrapped:
    """Crée un compte utilisateur (réservé admin).

    Seul point d'entrée d'onboarding tant que `POST /v1/auth/register` reste 403.
    L'inscription publique n'est PAS réouverte : cette route est protégée par
    Basic Auth admin et ne réactive jamais le register public.
    """
    # id généré explicitement → réponse construite sans dépendre d'un refresh
    # post-commit (évite un 500 si le refresh échoue alors que l'user est créé).
    user = User(
        id=uuid.uuid4(),
        email=body.email.strip().lower(),
        hashed_password=hash_password(body.password),
        is_beta=body.is_beta,
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise conflict("EMAIL_ALREADY_EXISTS", "Un compte avec cet email existe déjà.") from None
    # Invariants d'un compte neuf : jamais abonné (RevenueCat le posera plus tard),
    # quota vierge. Pas de relecture nécessaire.
    _, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return CreateUserResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=False,
            monthly_reloads=0,
            monthly_reloads_max=monthly_reloads_max,
        )
    )


@router.post("/users/{user_id}/reset-quota", response_model=ResetQuotaResponseWrapped)
async def reset_user_quota(
    user_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ResetQuotaResponseWrapped:
    """Réinitialise le quota mensuel d'un utilisateur.

    `monthly_reloads = 0` + `monthly_reloads_reset_at = None` : la fenêtre sera
    ré-initialisée proprement au prochain réimport via la logique lazy de
    `app/services/imports.py` (cohérent avec le hardening quota Story 7.2).
    """
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")
    # UPDATE atomique (pattern Story 7.2) : évite tout lost-update vs un réimport
    # concurrent qui incrémente monthly_reloads entre le read et le commit.
    # La réponse est construite à partir des valeurs connues post-reset
    # (monthly_reloads=0), sans relire l'objet.
    await db.execute(sa_update(User).where(User.id == user_id).values(monthly_reloads=0, monthly_reloads_reset_at=None))
    await db.commit()
    _, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return ResetQuotaResponseWrapped(
        data=UserBetaData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=0,
            monthly_reloads_max=monthly_reloads_max,
        )
    )


# ── Chantier 2 § 3 — Récupération de compte (côté admin seulement) ───────────

TEMPORARY_PASSWORD_LENGTH = 16


@router.post("/users/{user_id}/reset-password", response_model=ResetPasswordResponseWrapped)
async def reset_user_password(
    user_id: uuid.UUID,
    response: Response,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> ResetPasswordResponseWrapped:
    """Génère un mot de passe provisoire et déconnecte tous les appareils.

    Le mot de passe est renvoyé une seule fois et n'est jamais journalisé.
    `token_version + 1` (UPDATE atomique) invalide tous les jetons déjà émis.
    """
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")
    temporary_password = secrets.token_urlsafe(TEMPORARY_PASSWORD_LENGTH)[:TEMPORARY_PASSWORD_LENGTH]
    await db.execute(
        sa_update(User)
        .where(User.id == user_id)
        .values(hashed_password=hash_password(temporary_password), token_version=User.token_version + 1)
    )
    await db.commit()
    # Réponse porteuse d'un secret : jamais mise en cache (navigateur, proxy).
    response.headers["Cache-Control"] = "no-store"
    return ResetPasswordResponseWrapped(data=ResetPasswordData(temporary_password=temporary_password))


@router.get("/users/{user_id}", response_model=UserDetailResponseWrapped)
async def get_user_detail(
    user_id: uuid.UUID,
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
) -> UserDetailResponseWrapped:
    """Détail d'un utilisateur : champs + ses collèges + ses generation_jobs."""
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")

    colleges_result = await db.execute(
        select(College).where(College.user_id == user_id).order_by(College.created_at.desc())
    )
    colleges = colleges_result.scalars().all()

    jobs_result = await db.execute(
        select(GenerationJob).where(GenerationJob.user_id == user_id).order_by(GenerationJob.created_at.desc())
    )
    jobs = jobs_result.scalars().all()
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)

    return UserDetailResponseWrapped(
        data=UserDetailData(
            user_id=str(user.id),
            email=user.email,
            is_beta=user.is_beta,
            is_subscribed=user.is_subscribed,
            monthly_reloads=user.monthly_reloads,
            monthly_reloads_max=monthly_reloads_max,
            monthly_reloads_reset_at=(
                user.monthly_reloads_reset_at.isoformat() if user.monthly_reloads_reset_at else None
            ),
            created_at=user.created_at.isoformat() if user.created_at else None,
            colleges=[
                UserCollegeSummary(
                    college_id=str(c.id),
                    college_ref_id=c.college_ref_id,
                    status=c.status,
                    reload_count=c.reload_count,
                    reload_count_max=reload_count_max,
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
        )
    )
