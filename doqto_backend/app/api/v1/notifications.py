from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import NETWORK_PAGE_SIZE, RATE_LIMIT_READS_PER_MINUTE
from app.core.dependencies import get_current_user
from app.core.rate_limit import enforce_rate_limit
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.models import User
from app.schemas.common import OkResponse
from app.schemas.network import CursorPage
from app.schemas.notification import NotificationOut, NotificationReadIn, UnreadCountOut
from app.services.notification_service import NotificationService

router = APIRouter()


@router.get(ApiRoutes.NOTIFICATIONS_LIST, response_model=CursorPage)
async def list_notifications(
    unread_only: bool = Query(default=False),
    cursor: str | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CursorPage:
    await enforce_rate_limit(user.id, "list_notifications", RATE_LIMIT_READS_PER_MINUTE)
    after: datetime | None = None
    if cursor:
        try:
            after = datetime.fromisoformat(cursor)
        except ValueError as e:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="invalid_cursor") from e
    rows = await NotificationService.list(
        db=db,
        user_id=user.id,
        unread_only=unread_only,
        cursor=after,
        limit=NETWORK_PAGE_SIZE + 1,
    )
    next_cursor = None
    if len(rows) > NETWORK_PAGE_SIZE:
        rows = rows[:NETWORK_PAGE_SIZE]
        next_cursor = rows[-1].created_at.isoformat()
    return CursorPage(
        data=[NotificationOut.model_validate(r).model_dump(mode="json") for r in rows],
        next_cursor=next_cursor,
    )


@router.post(ApiRoutes.NOTIFICATIONS_READ, response_model=OkResponse)
async def mark_read(
    body: NotificationReadIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    if not body.all and not body.ids:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="ids_or_all_required")
    await NotificationService.mark_read(
        db=db, user_id=user.id, ids=body.ids, mark_all=body.all
    )
    await db.commit()
    return OkResponse()


@router.get(ApiRoutes.NOTIFICATIONS_UNREAD_COUNT, response_model=UnreadCountOut)
async def unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UnreadCountOut:
    count = await NotificationService.unread_count(db=db, user_id=user.id)
    return UnreadCountOut(unread_count=count)
