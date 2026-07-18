"""Factory + auth helpers shared by all backend tests."""
from __future__ import annotations

import random
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import ACCESS_TOKEN_TTL_SECONDS
from app.core.enums import ConversationType, JwtTokenType, OrgRole
from app.core.redis_keys import session_key
from app.core.security import create_token
from app.db.redis import get_redis
from app.models import Conversation, ConversationMember, Organization, OrgMember, User


def _digits(n: int) -> str:
    return "".join(random.choices("0123456789", k=n))


async def create_user(db: AsyncSession, *, full_name: str = "Dr Test") -> User:
    user = User(
        phone=f"+1{_digits(10)}",
        full_name=full_name,
        npi_number=_digits(10),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def create_org(db: AsyncSession, *, name: str = "Test Clinic") -> Organization:
    org = Organization(name=name, invite_code=uuid.uuid4().hex[:9].upper())
    db.add(org)
    await db.commit()
    await db.refresh(org)
    return org


async def add_org_member(
    db: AsyncSession, org: Organization, user: User, role: OrgRole = OrgRole.DOCTOR
) -> OrgMember:
    member = OrgMember(org_id=org.id, user_id=user.id, org_role=role)
    db.add(member)
    await db.commit()
    return member


async def create_conversation(
    db: AsyncSession,
    org: Organization,
    users: list[User],
    *,
    conv_type: ConversationType = ConversationType.DIRECT,
    name: str | None = None,
) -> Conversation:
    conv = Conversation(
        org_id=org.id, type=conv_type, name=name, created_by=users[0].id
    )
    db.add(conv)
    await db.flush()
    for u in users:
        db.add(ConversationMember(conversation_id=conv.id, user_id=u.id))
    await db.commit()
    await db.refresh(conv)
    return conv


def access_token(user_id: uuid.UUID) -> str:
    token, _ = create_token(user_id, JwtTokenType.ACCESS)
    return token


async def auth_headers(user_id: uuid.UUID) -> dict[str, str]:
    """Bearer headers backed by a live Redis session (jti check in get_current_user)."""
    token, jti = create_token(user_id, JwtTokenType.ACCESS)
    redis = await get_redis()
    await redis.setex(session_key(jti), ACCESS_TOKEN_TTL_SECONDS, "1")
    return {"Authorization": f"Bearer {token}"}
