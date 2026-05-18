import asyncio
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    JWTError,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.core.limiter import limiter
from app.deps import get_current_user, get_db
from app.models.user import User
from app.core.config import settings
from app.schemas.auth import LoginRequest, ProfileUpdateRequest, RefreshRequest, RegisterRequest, TokenResponse

router = APIRouter(tags=["auth"])


@router.post("/register", status_code=200)
async def register(body: RegisterRequest):
    raise HTTPException(
        status_code=403,
        detail={"code": "REGISTRATION_DISABLED", "message": "Les inscriptions sont fermées."},
    )


@router.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(body.password, user.hashed_password):
        raise HTTPException(
            status_code=401,
            detail={"code": "INVALID_CREDENTIALS", "message": "Identifiants incorrects"},
        )

    token_response = TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
    )
    return {"data": token_response.model_dump()}


@router.post("/refresh")
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise JWTError("Not a refresh token")
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail={"code": "TOKEN_EXPIRED", "message": "Refresh token invalide ou expiré"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail={"code": "TOKEN_EXPIRED", "message": "Refresh token invalide ou expiré"},
        )
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=401,
            detail={"code": "TOKEN_EXPIRED", "message": "Refresh token invalide ou expiré"},
        )
    user = await db.get(User, user_uuid)
    if not user:
        raise HTTPException(
            status_code=401,
            detail={"code": "USER_NOT_FOUND", "message": "Utilisateur introuvable"},
        )

    token_response = TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=body.refresh_token,
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
    )
    return {"data": token_response.model_dump()}


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "data": {
            "id": str(current_user.id),
            "email": current_user.email,
            "is_beta": current_user.is_beta,
            "is_subscribed": current_user.is_subscribed,
            "first_name": current_user.first_name,
            "year_group": current_user.year_group,
            "faculty": current_user.faculty,
            "monthly_reloads": current_user.monthly_reloads,
            "monthly_reloads_max": settings.monthly_reloads_max,
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
    await db.delete(current_user)
    await db.commit()
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
