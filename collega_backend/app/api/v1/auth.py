import asyncio
import logging
import secrets
import time
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import token_store
from app.core.errors import forbidden, unauthorized
from app.core.limiter import limiter
from app.core.security import (
    JWTError,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    token_version_ok,
    verify_password,
)
from app.core.time_utils import next_month_reset
from app.deps import get_current_user, get_db
from app.models.college import College
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    ProfileUpdateRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services import app_settings
from app.services.content.purge import delete_college_pdfs, purge_unreferenced_content

logger = logging.getLogger(__name__)
router = APIRouter(tags=["auth"])

# Hash factice calculé une fois : un e-mail inconnu coûte le même bcrypt qu'un mauvais
# mot de passe (temps de réponse identique, pas d'énumération des comptes).
_DUMMY_HASH = hash_password(secrets.token_urlsafe(16))


def _remaining_lifetime_s(payload: dict) -> int:
    """Secondes restantes avant `exp` (1 s minimum : la clé Redis doit exister)."""
    exp = payload.get("exp")
    if not isinstance(exp, int | float):
        return 1
    return max(1, int(exp - time.time()))


def _token_pair(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(str(user.id), user.token_version),
        refresh_token=create_refresh_token(str(user.id), user.token_version),
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
    )


@router.post("/register", status_code=200)
async def register(body: RegisterRequest):
    raise forbidden("REGISTRATION_DISABLED", "Les inscriptions sont fermées.")


@router.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    # Normalisation identique à la création admin (strip + lower) pour que la
    # connexion soit insensible à la casse / aux espaces saisis.
    email = body.email.strip().lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is None:
        verify_password(body.password, _DUMMY_HASH)
        raise unauthorized("INVALID_CREDENTIALS", "Identifiants incorrects")
    if not verify_password(body.password, user.hashed_password):
        raise unauthorized("INVALID_CREDENTIALS", "Identifiants incorrects")

    return {"data": _token_pair(user).model_dump()}


@router.post("/refresh")
@limiter.limit("30/minute")
async def refresh(request: Request, body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Rotation (chantier 2 § 2) : chaque renouvellement révoque le refresh présenté et
    émet un nouveau couple. Un refresh révoqué depuis plus de 60 s qui revient = vol
    présumé → `token_version` incrémentée (toutes les sessions coupées)."""
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise JWTError("Not a refresh token")
    except JWTError:
        raise unauthorized("TOKEN_EXPIRED", "Refresh token invalide ou expiré") from None

    user_id = payload.get("sub")
    if not user_id:
        raise unauthorized("TOKEN_EXPIRED", "Refresh token invalide ou expiré")
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise unauthorized("TOKEN_EXPIRED", "Refresh token invalide ou expiré") from None
    user = await db.get(User, user_uuid)
    if not user:
        raise unauthorized("USER_NOT_FOUND", "Utilisateur introuvable")
    if not token_version_ok(payload, user.token_version):
        raise unauthorized("TOKEN_REVOKED", "Session révoquée — reconnectez-vous")

    jti = payload.get("jti")
    # Jeton émis avant le chantier 2 (sans `jti`) : pas de révocation possible, il est
    # simplement remplacé par un couple rotatif.
    if isinstance(jti, str) and jti:
        # Révocation atomique « premier arrivé » : l'état renvoyé est celui d'avant l'appel.
        state = await token_store.revoke_refresh(jti, _remaining_lifetime_s(payload))
        if state == "reused":
            # UPDATE atomique : deux réutilisations concurrentes incrémentent bien deux fois.
            await db.execute(sa_update(User).where(User.id == user.id).values(token_version=User.token_version + 1))
            await db.commit()
            logger.warning("Réutilisation d'un refresh token révoqué : sessions coupées (user=%s)", user.id)
            raise unauthorized("TOKEN_REUSED", "Session révoquée — reconnectez-vous")
        # "active" : révoqué par cette requête ; "grace" : révoqué il y a moins de 60 s par
        # une requête parallèle → accepté sans toucher à l'état existant.

    return {"data": _token_pair(user).model_dump()}


@router.post("/logout", status_code=204)
async def logout(
    body: LogoutRequest | None = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Déconnexion serveur (idempotente) : révoque le refresh fourni s'il appartient à
    l'utilisatrice et efface le jeton APNs (plus de notifications sur cet appareil)."""
    if body is not None and body.refresh_token:
        try:
            payload = decode_token(body.refresh_token)
        except JWTError:
            payload = None
        jti = payload.get("jti") if payload else None
        if (
            payload is not None
            and payload.get("type") == "refresh"
            and payload.get("sub") == str(current_user.id)
            and isinstance(jti, str)
            and jti
        ):
            # Sans grâce : un refresh déconnecté est refusé immédiatement (TOKEN_REUSED).
            await token_store.revoke_refresh(jti, _remaining_lifetime_s(payload), grace=False)
    current_user.apns_token = None
    await db.commit()
    return Response(status_code=204)


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # Quota du mois en cours : le compteur stocké n'est remis à zéro qu'au
    # prochain réimport ; passé la date, il n'est plus le bon (Profil, story 8.14).
    now = datetime.now(UTC)
    reset_at = current_user.monthly_reloads_reset_at
    if reset_at is None or now >= reset_at:
        monthly_reloads, reset_at = 0, next_month_reset(now)
    else:
        monthly_reloads = current_user.monthly_reloads
    _, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    return {
        "data": {
            "id": str(current_user.id),
            "email": current_user.email,
            "is_beta": current_user.is_beta,
            "is_subscribed": current_user.is_subscribed,
            "first_name": current_user.first_name,
            "year_group": current_user.year_group,
            "faculty": current_user.faculty,
            "monthly_reloads": monthly_reloads,
            "monthly_reloads_max": monthly_reloads_max,
            "monthly_reloads_reset_at": reset_at.isoformat(),
            "reminder_hour_utc": current_user.reminder_hour_utc,
        }
    }


@router.patch("/profile")
async def update_profile(
    body: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.first_name is not None:
        current_user.first_name = body.first_name.strip() or None
    if body.year_group is not None:
        current_user.year_group = body.year_group.strip() or None
    if body.faculty is not None:
        current_user.faculty = body.faculty.strip() or None
    await db.commit()
    await db.refresh(current_user)
    return {
        "data": {
            "first_name": current_user.first_name,
            "year_group": current_user.year_group,
            "faculty": current_user.faculty,
        }
    }


@router.delete("/account", status_code=200)
@limiter.limit("3/minute")
async def delete_account(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    college_ids = list((await db.execute(select(College.id).where(College.user_id == current_user.id))).scalars())
    await db.delete(current_user)
    await db.commit()
    # Suppression « immédiate et complète » (politique de confidentialité) : PDF des
    # collèges et contenu qui n'appartenait qu'à ce compte. Best-effort : la
    # suppression du compte est déjà faite, le cron de nuit rattrape un échec.
    for college_id in college_ids:
        delete_college_pdfs(college_id)
    try:
        await purge_unreferenced_content(db)
        await db.commit()
    except Exception:  # noqa: BLE001
        logger.warning("Purge du contenu après suppression de compte reportée au cron", exc_info=True)
    return {"data": {"message": "Account deleted"}}


@router.post("/refresh-subscription")
async def refresh_subscription(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Attend que le webhook RevenueCat ait mis à jour is_subscribed (max 10 s, 5 × 2 s)."""
    if current_user.is_subscribed or current_user.is_beta:
        return {"data": {"is_subscribed": current_user.is_subscribed, "is_beta": current_user.is_beta}}

    for _ in range(5):
        await asyncio.sleep(2)
        db.expire(current_user)
        await db.refresh(current_user)
        if current_user.is_subscribed:
            break

    return {"data": {"is_subscribed": current_user.is_subscribed, "is_beta": current_user.is_beta}}
