from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, LargeBinary, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import MessageType, TranscriptStatus
from app.db.postgres import Base
from app.db.tables import Tables


class Message(Base):
    __tablename__ = Tables.MESSAGES

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.CONVERSATIONS}.id"),
        nullable=False,
        index=True,
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=False, index=True
    )
    type: Mapped[MessageType] = mapped_column(String(20), nullable=False)
    # Per-conversation sequence number (1, 2, 3, …) — unique index
    # uq_messages_conv_seq. Clients use it for gapless catch-up sync.
    seq: Mapped[int] = mapped_column(BigInteger, nullable=False)
    # Client-generated idempotency key; unique per conversation (partial index).
    client_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    content_encrypted: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    s3_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    file_size_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    voice_duration_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Voice-note transcripts are PHI — encrypted at rest like message bodies.
    transcript_encrypted: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    transcript_status: Mapped[TranscriptStatus] = mapped_column(
        String(20), default=TranscriptStatus.NONE, nullable=False
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class MessageReceipt(Base):
    __tablename__ = Tables.MESSAGE_RECEIPTS

    message_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.MESSAGES}.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), primary_key=True
    )
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
