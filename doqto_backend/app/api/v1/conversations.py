from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.ws_manager import ws_manager
from app.core.constants import (
    CHAT_LIST_PREVIEW_MAX_LEN,
    DISAPPEAR_OPTIONS_SEC,
    MESSAGES_PAGE_SIZE,
)
from app.core.security import decrypt_message
from app.core.dependencies import get_current_user
from app.core.enums import ConversationType, MessageType, WsEventServer
from app.core.rate_limit import enforce_rate_limit
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.models import Conversation, ConversationMember, Message, OrgMember, User
from app.schemas.common import OkResponse
from app.schemas.conversation import (
    ConversationAddMembersIn,
    ConversationCreateIn,
    ConversationOut,
    ConversationSettingsIn,
)
from app.schemas.message import MessageOut, MessageSendIn
from app.services.message_service import MessageError, MessageService

router = APIRouter()


async def _assert_member(conversation_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession) -> Conversation:
    conv = await db.scalar(select(Conversation).where(Conversation.id == conversation_id))
    if conv is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="conversation_not_found")
    member = await db.scalar(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conversation_id,
            ConversationMember.user_id == user_id,
        )
    )
    if member is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="not_a_conversation_member")
    return conv


def _preview_for(msg: Message | None) -> str | None:
    if msg is None or msg.content_encrypted is None or msg.type not in (
        MessageType.TEXT,
        MessageType.SYSTEM,
    ):
        return None
    try:
        text = decrypt_message(msg.content_encrypted)
    except Exception:
        return None
    text = text.strip()
    if len(text) > CHAT_LIST_PREVIEW_MAX_LEN:
        text = text[: CHAT_LIST_PREVIEW_MAX_LEN - 1].rstrip() + "…"
    return text


def _to_out(
    conv: Conversation,
    member_ids: list[uuid.UUID],
    last_msg: Message | None = None,
) -> ConversationOut:
    out = ConversationOut.model_validate(conv)
    out.member_ids = member_ids
    if last_msg is not None:
        out.last_message_at = last_msg.created_at
        out.last_message_sender_id = last_msg.sender_id
        out.last_message_type = last_msg.type
        out.last_message_preview = _preview_for(last_msg)
    return out


@router.get(ApiRoutes.CONVERSATIONS_LIST, response_model=list[ConversationOut])
async def list_conversations(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[ConversationOut]:
    convs = await MessageService.list_for_user(user_id=user.id, db=db)
    conv_ids = [c.id for c in convs]
    # Batched: 4 queries total regardless of conversation count (was ~2×N).
    latest = await MessageService.latest_per_conversation(conversation_ids=conv_ids, db=db)
    conv_members = await MessageService.members_by_conversation(
        conversation_ids=conv_ids, db=db
    )
    unread = await MessageService.unread_counts(
        conversation_ids=conv_ids, user_id=user.id, db=db
    )
    other_ids: set[uuid.UUID] = set()
    for c in convs:
        if c.type == ConversationType.DIRECT:
            other_ids.update(uid for uid in conv_members[c.id] if uid != user.id)
    names: dict[uuid.UUID, str] = {}
    if other_ids:
        rows = await db.execute(
            select(User.id, User.full_name).where(User.id.in_(other_ids))
        )
        names = dict(rows.all())
    out: list[ConversationOut] = []
    for c in convs:
        o = _to_out(c, conv_members[c.id], latest.get(c.id))
        if c.type == ConversationType.DIRECT:
            o.display_name = next(
                (names[uid] for uid in conv_members[c.id] if uid != user.id and uid in names),
                None,
            )
        o.unread_count = unread.get(c.id, 0)
        out.append(o)
    return out


@router.post(ApiRoutes.CONVERSATIONS_CREATE, response_model=ConversationOut)
async def create_conversation(
    body: ConversationCreateIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ConversationOut:
    # Use caller's org. For MVP, use the first org the caller belongs to.
    caller_org = await db.scalar(
        select(OrgMember.org_id).where(OrgMember.user_id == user.id).limit(1)
    )
    if caller_org is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="user_not_in_any_org")

    try:
        conv = await MessageService.create_conversation(
            org_id=caller_org,
            creator_id=user.id,
            conv_type=body.type,
            name=body.name,
            member_ids=body.member_ids,
            db=db,
        )
    except MessageError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e

    members = await MessageService.conversation_members(conversation_id=conv.id, db=db)
    out = _to_out(conv, [m.user_id for m in members])
    if conv.type == ConversationType.DIRECT:
        other_id = next((m.user_id for m in members if m.user_id != user.id), None)
        if other_id is not None:
            out.display_name = await db.scalar(
                select(User.full_name).where(User.id == other_id)
            )
    return out


@router.get(ApiRoutes.CONVERSATIONS_MESSAGES, response_model=list[MessageOut])
async def list_messages(
    conversation_id: uuid.UUID,
    before: datetime | None = Query(default=None),
    limit: int = Query(default=MESSAGES_PAGE_SIZE, ge=1, le=MESSAGES_PAGE_SIZE),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MessageOut]:
    await _assert_member(conversation_id, user.id, db)
    msgs = await MessageService.list_messages(
        conversation_id=conversation_id, before=before, limit=limit, db=db
    )
    read_ids = await MessageService.read_message_ids(
        message_ids=[m.id for m in msgs], db=db
    )
    delivered_ids = await MessageService.delivered_message_ids(
        message_ids=[m.id for m in msgs], db=db
    )
    return [
        MessageService.to_out(m, read=m.id in read_ids, delivered=m.id in delivered_ids)
        for m in msgs
    ]


@router.post(ApiRoutes.CONVERSATIONS_MESSAGES, response_model=MessageOut)
async def send_message(
    conversation_id: uuid.UUID,
    body: MessageSendIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    await enforce_rate_limit(user.id, "send_message")
    conv = await _assert_member(conversation_id, user.id, db)
    try:
        msg = await MessageService.send_text(
            conversation_id=conversation_id,
            sender_id=user.id,
            content=body.content,
            db=db,
            client_id=body.client_id,
        )
    except MessageError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e

    out = MessageService.to_out(msg)
    recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
    await db.commit()  # flush before broadcasting so receivers can query
    await ws_manager.publish_to_users(
        conv.org_id,
        recipients,
        WsEventServer.NEW_MESSAGE,
        out.model_dump(mode="json"),
    )
    return out


@router.post(ApiRoutes.CONVERSATIONS_READ, response_model=OkResponse)
async def mark_conversation_read(
    conversation_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    conv = await _assert_member(conversation_id, user.id, db)
    await MessageService.mark_conversation_read(
        conversation_id=conversation_id, user_id=user.id, db=db
    )
    recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
    await db.commit()
    # One conversation-level event: senders flip all their ticks to read.
    await ws_manager.publish_to_users(
        conv.org_id,
        recipients,
        WsEventServer.MESSAGE_READ,
        {"conversation_id": str(conversation_id), "user_id": str(user.id)},
    )
    return OkResponse()


@router.post(ApiRoutes.CONVERSATIONS_DELIVERED, response_model=OkResponse)
async def mark_conversation_delivered(
    conversation_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    """Recipient acks receipt of a conversation's messages → gray double-check
    on the sender's side. Called by clients whenever messages arrive."""
    conv = await _assert_member(conversation_id, user.id, db)
    changed = await MessageService.mark_conversation_delivered(
        conversation_id=conversation_id, user_id=user.id, db=db
    )
    if changed:
        recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
        await db.commit()
        await ws_manager.publish_to_users(
            conv.org_id,
            recipients,
            WsEventServer.MESSAGE_DELIVERED,
            {"conversation_id": str(conversation_id), "user_id": str(user.id)},
        )
    return OkResponse()


@router.patch(ApiRoutes.CONVERSATIONS_MEMBERS, response_model=OkResponse)
async def add_members(
    conversation_id: uuid.UUID,
    body: ConversationAddMembersIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    conv = await _assert_member(conversation_id, user.id, db)
    added: list[uuid.UUID] = []
    for uid in body.user_ids:
        exists = await db.scalar(
            select(ConversationMember).where(
                ConversationMember.conversation_id == conversation_id,
                ConversationMember.user_id == uid,
            )
        )
        if exists is None:
            db.add(ConversationMember(conversation_id=conversation_id, user_id=uid))
            added.append(uid)
    if added:
        await db.flush()  # member_ids below must see the new rows
        recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
        for uid in added:
            await ws_manager.publish_to_users(
                conv.org_id,
                recipients,
                WsEventServer.MEMBER_ADDED,
                {"conversation_id": str(conversation_id), "user_id": str(uid)},
            )
    return OkResponse()


@router.delete(ApiRoutes.CONVERSATIONS_MEMBER_DETAIL, response_model=OkResponse)
async def remove_or_leave(
    conversation_id: uuid.UUID,
    user_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    conv = await _assert_member(conversation_id, user.id, db)
    target = await db.scalar(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conversation_id,
            ConversationMember.user_id == user_id,
        )
    )
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="member_not_found")
    await db.delete(target)
    await db.flush()
    # Remaining members + the removed user (they need to see themselves leave).
    recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
    await ws_manager.publish_to_users(
        conv.org_id,
        [*recipients, user_id],
        WsEventServer.MEMBER_REMOVED,
        {"conversation_id": str(conversation_id), "user_id": str(user_id)},
    )
    return OkResponse()


@router.patch(ApiRoutes.CONVERSATIONS_SETTINGS, response_model=OkResponse)
async def update_settings(
    conversation_id: uuid.UUID,
    body: ConversationSettingsIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    conv = await _assert_member(conversation_id, user.id, db)
    val = body.disappear_after_sec
    if val is not None and val not in DISAPPEAR_OPTIONS_SEC:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, detail="invalid_disappear_after_sec"
        )
    if conv.disappear_after_sec == val:
        return OkResponse()  # idempotent — no duplicate banner
    conv.disappear_after_sec = val

    if val is None:
        text = f"{user.full_name} turned off disappearing messages."
    else:
        text = (
            f"{user.full_name} turned on disappearing messages. New messages will "
            f"disappear from this chat {DISAPPEAR_OPTIONS_SEC[val]} after they're sent."
        )
    msg = await MessageService.send_system(conv=conv, sender_id=user.id, content=text, db=db)
    out = MessageService.to_out(msg)
    recipients = await MessageService.member_ids(conversation_id=conversation_id, db=db)
    await db.commit()  # flush before broadcasting so receivers can query
    # Broadcast as NEW_MESSAGE: clients already insert it into the open thread and
    # refresh the conversation list (which refetches disappear_after_sec).
    await ws_manager.publish_to_users(
        conv.org_id, recipients, WsEventServer.NEW_MESSAGE, out.model_dump(mode="json")
    )
    return OkResponse()
