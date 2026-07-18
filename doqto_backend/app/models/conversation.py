from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import ConversationType
from app.db.postgres import Base
from app.db.tables import Tables


class Conversation(Base):
    __tablename__ = Tables.CONVERSATIONS

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    org_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.ORGANIZATIONS}.id"),
        nullable=False,
        index=True,
    )
    type: Mapped[ConversationType] = mapped_column(String(10), nullable=False)
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=True
    )
    disappear_after_sec: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Highest message seq handed out — bumped atomically by MessageService.next_seq().
    last_seq: Mapped[int] = mapped_column(
        BigInteger, default=0, server_default="0", nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class ConversationMember(Base):
    __tablename__ = Tables.CONVERSATION_MEMBERS
    __table_args__ = (UniqueConstraint("conversation_id", "user_id"),)

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.CONVERSATIONS}.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=False, index=True
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
