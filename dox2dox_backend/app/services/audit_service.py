from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import AuditAction
from app.models import AuditLog


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
