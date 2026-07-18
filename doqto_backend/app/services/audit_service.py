from __future__ import annotations

import uuid
from typing import Any

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import AuditAction
from app.models import AuditLog


def request_meta(request: Request) -> tuple[str | None, str | None]:
    """(ip, user_agent) for audit rows. IP honours the first X-Forwarded-For hop."""
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        ip = fwd.split(",")[0].strip() or None
    else:
        ip = request.client.host if request.client else None
    return ip, request.headers.get("user-agent")


class AuditService:
    @staticmethod
    async def log(
        db: AsyncSession,
        *,
        user_id: uuid.UUID | None,
        action: AuditAction,
        resource_type: str | None = None,
        resource_id: uuid.UUID | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        entry = AuditLog(
            user_id=user_id,
            action=action.value,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=ip_address,
            user_agent=user_agent,
            meta=metadata,
        )
        db.add(entry)
        await db.flush()

    @staticmethod
    async def log_request(
        request: Request,
        *,
        user_id: uuid.UUID | None,
        action: AuditAction,
        db: AsyncSession,
        resource_type: str | None = None,
        resource_id: uuid.UUID | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Like log(), but populates ip_address/user_agent from the request."""
        ip, user_agent = request_meta(request)
        await AuditService.log(
            db,
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=ip,
            user_agent=user_agent,
            metadata=metadata,
        )
