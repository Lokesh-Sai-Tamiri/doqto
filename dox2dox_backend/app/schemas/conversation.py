from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.core.enums import ConversationType, MessageType
from app.schemas.common import ORMModel


class ConversationCreateIn(BaseModel):
    type: ConversationType
    name: str | None = Field(default=None, max_length=100)
    member_ids: list[uuid.UUID] = Field(min_length=1)


class ConversationSettingsIn(BaseModel):
    disappear_after_sec: int | None = None


class ConversationAddMembersIn(BaseModel):
    user_ids: list[uuid.UUID] = Field(min_length=1)


class ConversationOut(ORMModel):
    id: uuid.UUID
    org_id: uuid.UUID
    type: ConversationType
    name: str | None
    created_by: uuid.UUID | None
    disappear_after_sec: int | None
    created_at: datetime
    updated_at: datetime
    member_ids: list[uuid.UUID] = []
    last_message_at: datetime | None = None
    last_message_preview: str | None = None
    last_message_sender_id: uuid.UUID | None = None
    last_message_type: MessageType | None = None
    unread_count: int = 0
