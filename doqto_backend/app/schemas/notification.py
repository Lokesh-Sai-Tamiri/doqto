from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel

from app.schemas.common import ORMModel


class NotificationOut(ORMModel):
    id: uuid.UUID
    type: str
    actor_id: uuid.UUID | None = None
    subject_type: str | None = None
    subject_id: uuid.UUID | None = None
    payload: dict[str, Any] = {}
    read_at: datetime | None = None
    created_at: datetime


class NotificationReadIn(BaseModel):
    ids: list[uuid.UUID] | None = None
    all: bool = False


class UnreadCountOut(BaseModel):
    unread_count: int
