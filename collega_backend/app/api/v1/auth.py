import uuid

from fastapi import APIRouter, Depends, HTTPException
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
from app.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse

router = APIRouter(tags=["auth"])


@router.post("/register", status_code=201)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if len(body.password.strip()) < 8:
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_PASSWORD", "message": "Le mot de passe doit contenir au moins 8 caractères"},
        )
    result = await db.execute(select(User).where(User.email == body.email))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "EMAIL_ALREADY_EXISTS", "message": "Cet email est déjà utilisé"},
        )

    user = User(
        email=body.email,
        hashed_password=hash_password(body.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token_response = TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
    )
    return {"data": token_response.model_dump()}


@router.post("/login")
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
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
        }
    }
