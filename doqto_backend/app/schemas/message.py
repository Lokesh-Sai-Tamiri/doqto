from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.core.enums import MessageType, TranscriptStatus


class MessageSendIn(BaseModel):
    type: MessageType = MessageType.TEXT
    content: str = Field(min_length=1, max_length=5000)
    # Idempotency key (uuid from the client outbox); retries return the
    # original message instead of creating a duplicate.
    client_id: str | None = Field(default=None, max_length=64)


class MessageScheduleIn(BaseModel):
    content: str = Field(min_length=1, max_length=5000)
    # Wall-clock time in the picked zone, naive ISO ("2026-08-09T14:30:00").
    scheduled_local: str = Field(max_length=32)
    # IANA zone name ("Asia/Kolkata"); the server resolves the UTC instant so
    # DST rules live in one place (Python zoneinfo), not in every client.
    timezone: str = Field(max_length=64)


class ScheduledMessageOut(BaseModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    scheduled_at: datetime  # resolved UTC instant
    timezone: str
    status: str


class MessageOut(BaseModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    type: MessageType
    seq: int  # per-conversation sequence number (catch-up sync cursor)
    content: str | None
    s3_key: str | None
    file_name: str | None
    file_size_bytes: int | None
    voice_duration_sec: int | None
    transcript: str | None
    transcript_status: TranscriptStatus
    expires_at: datetime | None
    created_at: datetime
    read: bool = False  # read by a recipient (blue double-check)
    delivered: bool = False  # delivered to a recipient (gray double-check)
    client_id: str | None = None  # echoes the sender's idempotency key


class FileUrlOut(BaseModel):
    url: str
    expires_in: int
