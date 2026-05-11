from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import MESSAGES_PAGE_SIZE
from app.core.enums import AuditAction, ConversationType, MessageType, TranscriptStatus
from app.core.security import decrypt_message, encrypt_message
from app.models import (
    Conversation,
    ConversationMember,
    Message,
    MessageReceipt,
    User,
)
from app.schemas.message import MessageOut
from app.services.audit_service import AuditService


class MessageError(Exception):
    pass


class MessageService:
    @staticmethod
    async def create_conversation(
        *,
        org_id: uuid.UUID,
        creator_id: uuid.UUID,
        conv_type: ConversationType,
        name: str | None,
        member_ids: list[uuid.UUID],
        db: AsyncSession,
    ) -> Conversation:
        if conv_type == ConversationType.GROUP and not name:
            raise MessageError("group_name_required")
        if conv_type == ConversationType.DIRECT and len(member_ids) != 1:
            raise MessageError("direct_requires_one_member")

        full_member_ids = list({creator_id, *member_ids})
        if conv_type == ConversationType.DIRECT and len(full_member_ids) != 2:
            raise MessageError("direct_requires_two_distinct")

        # Reuse existing direct conversation if any.
        if conv_type == ConversationType.DIRECT:
            subq = (
                select(ConversationMember.conversation_id)
                .where(ConversationMember.user_id.in_(full_member_ids))
                .group_by(ConversationMember.conversation_id)
                .having(func.count() == 2)
                .subquery()
            )
            existing = await db.scalar(
                select(Conversation)
                .where(Conversation.id.in_(select(subq)))
                .where(Conversation.type == ConversationType.DIRECT)
                .where(Conversation.org_id == org_id)
                .limit(1)
            )
            if existing is not None:
                return existing

        conv = Conversation(
            org_id=org_id,
            type=conv_type,
            name=name,
            created_by=creator_id,
        )
        db.add(conv)
        await db.flush()
        for uid in full_member_ids:
            db.add(ConversationMember(conversation_id=conv.id, user_id=uid))
        await AuditService.log(
            db,
            user_id=creator_id,
            action=AuditAction.CONVERSATION_CREATED,
            resource_type="conversation",
            resource_id=conv.id,
        )
        return conv

    @staticmethod
    async def list_for_user(*, user_id: uuid.UUID, db: AsyncSession) -> list[Conversation]:
        rows = await db.execute(
            select(Conversation)
            .join(ConversationMember, ConversationMember.conversation_id == Conversation.id)
            .where(ConversationMember.user_id == user_id)
            .order_by(Conversation.updated_at.desc())
        )
        return list(rows.scalars().all())

    @staticmethod
    async def conversation_members(
        *, conversation_id: uuid.UUID, db: AsyncSession
    ) -> list[ConversationMember]:
        rows = await db.execute(
            select(ConversationMember).where(ConversationMember.conversation_id == conversation_id)
        )
        return list(rows.scalars().all())

    @staticmethod
    async def send_text(
        *,
        conversation_id: uuid.UUID,
        sender_id: uuid.UUID,
        content: str,
        db: AsyncSession,
    ) -> Message:
        conv = await db.scalar(select(Conversation).where(Conversation.id == conversation_id))
        if conv is None:
            raise MessageError("conversation_not_found")

        expires_at: datetime | None = None
        if conv.disappear_after_sec:
            expires_at = datetime.now(tz=timezone.utc) + timedelta(seconds=conv.disappear_after_sec)

        msg = Message(
            conversation_id=conversation_id,
            sender_id=sender_id,
            type=MessageType.TEXT,
            content_encrypted=encrypt_message(content),
            transcript_status=TranscriptStatus.NONE,
            expires_at=expires_at,
        )
        db.add(msg)
        conv.updated_at = datetime.now(tz=timezone.utc)
        await db.flush()
        await AuditService.log(
            db,
            user_id=sender_id,
            action=AuditAction.MESSAGE_SENT,
            resource_type="message",
            resource_id=msg.id,
        )
        return msg

    @staticmethod
    async def list_messages(
        *,
        conversation_id: uuid.UUID,
        before: datetime | None,
        limit: int,
        db: AsyncSession,
    ) -> list[Message]:
        stmt = select(Message).where(
            Message.conversation_id == conversation_id, Message.is_deleted.is_(False)
        )
        if before is not None:
            stmt = stmt.where(Message.created_at < before)
        stmt = stmt.order_by(Message.created_at.desc()).limit(min(limit, MESSAGES_PAGE_SIZE))
        rows = await db.execute(stmt)
        return list(rows.scalars().all())

    @staticmethod
    async def latest_per_conversation(
        *, conversation_ids: list[uuid.UUID], db: AsyncSession
    ) -> dict[uuid.UUID, Message]:
        """Return the most recent non-deleted message for each given conversation, keyed by conv id.

        Uses Postgres DISTINCT ON to fetch all latest messages in a single round-trip.
        """
        if not conversation_ids:
            return {}
        stmt = (
            select(Message)
            .where(Message.conversation_id.in_(conversation_ids))
            .where(Message.is_deleted.is_(False))
            .order_by(Message.conversation_id, Message.created_at.desc())
            .distinct(Message.conversation_id)
        )
        rows = await db.execute(stmt)
        return {m.conversation_id: m for m in rows.scalars().all()}

    @staticmethod
    def to_out(msg: Message) -> MessageOut:
        content = decrypt_message(msg.content_encrypted) if msg.content_encrypted else None
        return MessageOut(
            id=msg.id,
            conversation_id=msg.conversation_id,
            sender_id=msg.sender_id,
            type=msg.type,
            content=content,
            s3_key=msg.s3_key,
            file_name=msg.file_name,
            file_size_bytes=msg.file_size_bytes,
            voice_duration_sec=msg.voice_duration_sec,
            transcript=msg.transcript,
            transcript_status=msg.transcript_status,
            expires_at=msg.expires_at,
            created_at=msg.created_at,
        )

    @staticmethod
    async def mark_read(
        *, message_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
    ) -> None:
        existing = await db.scalar(
            select(MessageReceipt).where(
                MessageReceipt.message_id == message_id, MessageReceipt.user_id == user_id
            )
        )
        now = datetime.now(tz=timezone.utc)
        if existing is None:
            db.add(MessageReceipt(message_id=message_id, user_id=user_id, delivered_at=now, read_at=now))
        else:
            existing.read_at = now
            if not existing.delivered_at:
                existing.delivered_at = now
        await AuditService.log(
            db,
            user_id=user_id,
            action=AuditAction.MESSAGE_READ,
            resource_type="message",
            resource_id=message_id,
        )
