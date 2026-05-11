from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.ws_manager import ws_manager
from app.core.constants import CHAT_LIST_PREVIEW_MAX_LEN, MESSAGES_PAGE_SIZE
from app.core.security import decrypt_message
from app.core.dependencies import get_current_user
from app.core.enums import MessageType, WsEventServer
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
    if msg is None or msg.type != MessageType.TEXT or msg.content_encrypted is None:
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
    latest = await MessageService.latest_per_conversation(
        conversation_ids=[c.id for c in convs], db=db
    )
    out: list[ConversationOut] = []
    for c in convs:
        members = await MessageService.conversation_members(conversation_id=c.id, db=db)
        out.append(_to_out(c, [m.user_id for m in members], latest.get(c.id)))
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
    return _to_out(conv, [m.user_id for m in members])


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
    return [MessageService.to_out(m) for m in msgs]


@router.post(ApiRoutes.CONVERSATIONS_MESSAGES, response_model=MessageOut)
async def send_message(
    conversation_id: uuid.UUID,
    body: MessageSendIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    conv = await _assert_member(conversation_id, user.id, db)
    try:
        msg = await MessageService.send_text(
            conversation_id=conversation_id,
            sender_id=user.id,
            content=body.content,
            db=db,
        )
    except MessageError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e

    out = MessageService.to_out(msg)
    await db.commit()  # flush before broadcasting so receivers can query
    await ws_manager.broadcast_org(
        conv.org_id,
        WsEventServer.NEW_MESSAGE,
        out.model_dump(mode="json"),
    )
    return out


@router.patch(ApiRoutes.CONVERSATIONS_MEMBERS, response_model=OkResponse)
async def add_members(
    conversation_id: uuid.UUID,
    body: ConversationAddMembersIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    conv = await _assert_member(conversation_id, user.id, db)
    for uid in body.user_ids:
        exists = await db.scalar(
            select(ConversationMember).where(
                ConversationMember.conversation_id == conversation_id,
                ConversationMember.user_id == uid,
            )
        )
        if exists is None:
            db.add(ConversationMember(conversation_id=conversation_id, user_id=uid))
            await ws_manager.broadcast_org(
                conv.org_id,
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
    await ws_manager.broadcast_org(
        conv.org_id,
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
    conv.disappear_after_sec = body.disappear_after_sec
    return OkResponse()
