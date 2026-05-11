from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.core.enums import MessageType, TranscriptStatus


class MessageSendIn(BaseModel):
    type: MessageType = MessageType.TEXT
    content: str = Field(min_length=1, max_length=5000)


class MessageOut(BaseModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    type: MessageType
    content: str | None
    s3_key: str | None
    file_name: str | None
    file_size_bytes: int | None
    voice_duration_sec: int | None
    transcript: str | None
    transcript_status: TranscriptStatus
    expires_at: datetime | None
    created_at: datetime


class FileUrlOut(BaseModel):
    url: str
    expires_in: int
