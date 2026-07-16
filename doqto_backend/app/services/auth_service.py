from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timezone

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.constants import (
    DEV_MASTER_OTP,
    OTP_LENGTH,
    OTP_MAX_ATTEMPTS,
    OTP_RESEND_COOLDOWN_SECONDS,
    OTP_TTL_SECONDS,
    RATE_LIMIT_OTP_PER_HOUR,
    REFRESH_TOKEN_TTL_SECONDS,
)
from app.core.enums import AuditAction, JwtTokenType, UserRole
from app.core.redis_keys import otp_attempts_key, otp_key, otp_resend_key, rate_limit_key, session_key
from app.core.security import TokenError, create_token, decode_token
from app.models import User
from app.schemas.auth import TokenPair
from app.services.audit_service import AuditService
from app.services.fakes import FakeSNSClient


class AuthError(Exception):
    pass


def _generate_otp() -> str:
    return "".join(str(secrets.randbelow(10)) for _ in range(OTP_LENGTH))


def _sns() -> FakeSNSClient:
    # Swap to real boto3 SNS client in staging/prod — wire from config.
    return FakeSNSClient()


class AuthService:
    @staticmethod
    async def request_otp(*, phone: str, redis: Redis, db: AsyncSession) -> None:
        # Resend cooldown: prevents overwriting an OTP the user is actively
        # typing (e.g. accidental double-tap on "Send code").
        cooldown_key = otp_resend_key(phone)
        if await redis.exists(cooldown_key):
            raise AuthError("otp_resend_cooldown")

        # Hourly rate limit per phone. Guards SMS budget and basic DoS.
        rl_key = rate_limit_key(phone, "request_otp")
        count = int(await redis.get(rl_key) or 0)
        if count >= RATE_LIMIT_OTP_PER_HOUR:
            raise AuthError("otp_too_many_requests")

        code = _generate_otp()
        await redis.setex(otp_key(phone), OTP_TTL_SECONDS, code)
        await redis.delete(otp_attempts_key(phone))
        await redis.setex(cooldown_key, OTP_RESEND_COOLDOWN_SECONDS, "1")
        if count == 0:
            await redis.setex(rl_key, 3600, 1)
        else:
            await redis.incr(rl_key)
        await _sns().send_otp(phone, code)
        await AuditService.log(db, user_id=None, action=AuditAction.OTP_REQUESTED, metadata={"phone": phone})

    @staticmethod
    async def verify_otp(
        *, phone: str, code: str, redis: Redis, db: AsyncSession
    ) -> TokenPair:
        # Dev master OTP — bypass Redis lookup when ENVIRONMENT=local.
        # Lets simulator/emulator testing skip the Redis-code step and the
        # attempt counter. Never honoured in staging/prod.
        if settings.is_local and code == DEV_MASTER_OTP:
            await redis.delete(otp_key(phone))
            await redis.delete(otp_attempts_key(phone))
        else:
            stored = await redis.get(otp_key(phone))
            attempts = int(await redis.get(otp_attempts_key(phone)) or 0)
            if attempts >= OTP_MAX_ATTEMPTS:
                raise AuthError("otp_too_many_attempts")
            if stored is None:
                raise AuthError("otp_expired")
            if stored != code:
                await redis.incr(otp_attempts_key(phone))
                await redis.expire(otp_attempts_key(phone), OTP_TTL_SECONDS)
                raise AuthError("otp_invalid")

            await redis.delete(otp_key(phone))
            await redis.delete(otp_attempts_key(phone))

        user = await db.scalar(select(User).where(User.phone == phone))
        if user is None:
            # Pre-register: create minimal user row. Registration endpoint fills the rest.
            user = User(
                phone=phone,
                full_name="",
                npi_number=f"PENDING{secrets.randbelow(100):02d}",
                role=UserRole.DOCTOR,
            )
            db.add(user)
            await db.flush()
            is_registered = False
        else:
            is_registered = bool(user.full_name and not user.npi_number.startswith("PENDING"))

        user.last_seen_at = datetime.now(tz=timezone.utc)
        await AuditService.log(db, user_id=user.id, action=AuditAction.OTP_VERIFIED)

        access, jti = create_token(user.id, JwtTokenType.ACCESS)
        refresh, _ = create_token(user.id, JwtTokenType.REFRESH, jti=jti)
        await redis.setex(session_key(jti), REFRESH_TOKEN_TTL_SECONDS, str(user.id))

        if is_registered:
            await AuditService.log(db, user_id=user.id, action=AuditAction.LOGIN)

        return TokenPair(access_token=access, refresh_token=refresh, is_registered=is_registered)

    @staticmethod
    async def refresh(*, refresh_token: str, redis: Redis) -> TokenPair:
        try:
            payload = decode_token(refresh_token, JwtTokenType.REFRESH)
        except TokenError as e:
            raise AuthError(str(e)) from e
        jti = payload.get("jti")
        user_id = payload.get("sub")
        if not jti or not user_id or not await redis.exists(session_key(jti)):
            raise AuthError("session_revoked")

        access, new_jti = create_token(user_id, JwtTokenType.ACCESS)
        refresh, _ = create_token(user_id, JwtTokenType.REFRESH, jti=new_jti)
        await redis.delete(session_key(jti))
        await redis.setex(session_key(new_jti), REFRESH_TOKEN_TTL_SECONDS, user_id)
        return TokenPair(access_token=access, refresh_token=refresh, is_registered=True)

    @staticmethod
    async def logout(*, access_token: str, redis: Redis, db: AsyncSession) -> None:
        try:
            payload = decode_token(access_token, JwtTokenType.ACCESS)
        except TokenError:
            return
        jti = payload.get("jti")
        user_id = payload.get("sub")
        if jti:
            await redis.delete(session_key(jti))
        if user_id:
            await AuditService.log(db, user_id=uuid.UUID(user_id), action=AuditAction.LOGOUT)

    @staticmethod
    async def complete_registration(
        *, user: User, full_name: str, specialty: str | None, npi_number: str, db: AsyncSession
    ) -> User:
        dup = await db.scalar(select(User).where(User.npi_number == npi_number, User.id != user.id))
        if dup is not None:
            raise AuthError("npi_already_registered")
        user.full_name = full_name
        user.specialty = specialty
        user.npi_number = npi_number
        await AuditService.log(db, user_id=user.id, action=AuditAction.REGISTER)
        return user
