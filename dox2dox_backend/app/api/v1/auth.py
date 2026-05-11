from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.db.redis import get_redis
from app.models import User
from app.schemas.auth import RefreshIn, RegisterIn, RequestOtpIn, TokenPair, VerifyOtpIn
from app.schemas.common import OkResponse
from app.schemas.user import UserOut, build_user_out
from app.services.auth_service import AuthError, AuthService

router = APIRouter()


@router.post(ApiRoutes.AUTH_REQUEST_OTP, response_model=OkResponse)
async def request_otp(
    body: RequestOtpIn, redis: Redis = Depends(get_redis), db: AsyncSession = Depends(get_db)
) -> OkResponse:
    try:
        await AuthService.request_otp(phone=body.phone, redis=redis, db=db)
    except AuthError as e:
        # 429 for rate-limit/cooldown errors so the client can surface a wait
        # message cleanly; other AuthErrors bubble as 400.
        detail = str(e)
        if detail in {"otp_resend_cooldown", "otp_too_many_requests"}:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail=detail) from e
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=detail) from e
    return OkResponse()


@router.post(ApiRoutes.AUTH_VERIFY_OTP, response_model=TokenPair)
async def verify_otp(
    body: VerifyOtpIn, redis: Redis = Depends(get_redis), db: AsyncSession = Depends(get_db)
) -> TokenPair:
    try:
        return await AuthService.verify_otp(phone=body.phone, code=body.code, redis=redis, db=db)
    except AuthError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail=str(e)) from e


@router.post(ApiRoutes.AUTH_REFRESH, response_model=TokenPair)
async def refresh(body: RefreshIn, redis: Redis = Depends(get_redis)) -> TokenPair:
    try:
        return await AuthService.refresh(refresh_token=body.refresh_token, redis=redis)
    except AuthError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail=str(e)) from e


@router.post(ApiRoutes.AUTH_LOGOUT, response_model=OkResponse)
async def logout(
    authorization: str | None = Header(default=None),
    redis: Redis = Depends(get_redis),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    if authorization and authorization.lower().startswith("bearer "):
        await AuthService.logout(access_token=authorization.split(" ", 1)[1], redis=redis, db=db)
    return OkResponse()


@router.post(ApiRoutes.AUTH_REGISTER, response_model=UserOut)
async def register(
    body: RegisterIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserOut:
    try:
        updated = await AuthService.complete_registration(
            user=user,
            full_name=body.full_name,
            specialty=body.specialty,
            npi_number=body.npi_number,
            db=db,
        )
    except AuthError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
    return await build_user_out(updated)
