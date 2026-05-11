"""Email + password auth for the Next.js admin panel.

Separate from the mobile OTP flow on purpose — admin has a stable credential
and a browser, doctors have a phone. Shares the same JWT format + Redis
session so the existing `get_current_user` dependency + `require_super_admin`
guard work unchanged downstream.
"""
from __future__ import annotations

from passlib.context import CryptContext
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import REFRESH_TOKEN_TTL_SECONDS
from app.core.enums import AuditAction, JwtTokenType, UserRole
from app.core.redis_keys import session_key
from app.core.security import create_token
from app.models import User
from app.schemas.auth import TokenPair
from app.services.audit_service import AuditService

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AdminAuthError(Exception):
    pass


class AdminAuthService:
    @staticmethod
    def hash_password(password: str) -> str:
        return _pwd.hash(password)

    @staticmethod
    async def login(
        *, email: str, password: str, redis: Redis, db: AsyncSession
    ) -> TokenPair:
        # Case-insensitive email lookup.
        user = await db.scalar(select(User).where(User.email == email.lower().strip()))
        # Intentionally identical error for "no such email" and "wrong password"
        # so the endpoint doesn't leak which email addresses are valid.
        if (
            user is None
            or user.password_hash is None
            or user.role != UserRole.SUPER_ADMIN
            or not _pwd.verify(password, user.password_hash)
        ):
            raise AdminAuthError("invalid_credentials")

        access, jti = create_token(user.id, JwtTokenType.ACCESS)
        refresh, _ = create_token(user.id, JwtTokenType.REFRESH, jti=jti)
        await redis.setex(session_key(jti), REFRESH_TOKEN_TTL_SECONDS, str(user.id))

        await AuditService.log(db, user_id=user.id, action=AuditAction.LOGIN, metadata={"via": "admin_panel"})
        return TokenPair(access_token=access, refresh_token=refresh, is_registered=True)
