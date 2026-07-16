from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.ws_manager import ws_manager
from app.core.constants import (
    FILE_MAX_BYTES,
    PRESIGNED_URL_TTL_SECONDS,
    VOICE_NOTE_MAX_FILE_BYTES,
)
from app.core.dependencies import get_current_user
from app.core.enums import (
    AuditAction,
    MessageType,
    TranscriptStatus,
    WsEventServer,
)
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.models import Conversation, ConversationMember, Message, User
from app.schemas.common import OkResponse
from app.schemas.message import FileUrlOut, MessageOut
from app.services.audit_service import AuditService
from app.services.file_service import FileService
from app.services.message_service import MessageService
from app.services.transcription_service import TranscriptionService

router = APIRouter()


async def _assert_conv_member(
    conversation_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
) -> Conversation:
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


@router.post("/upload/{conversation_id}", response_model=MessageOut)
async def upload_file(
    conversation_id: uuid.UUID,
    file: UploadFile,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    conv = await _assert_conv_member(conversation_id, user.id, db)
    data = await file.read()
    if len(data) > FILE_MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="file_too_large")

    msg = Message(
        conversation_id=conversation_id,
        sender_id=user.id,
        type=MessageType.FILE if not (file.content_type or "").startswith("image/") else MessageType.IMAGE,
        file_name=file.filename,
        file_size_bytes=len(data),
        expires_at=MessageService.expiry_for(conv),
    )
    db.add(msg)
    await db.flush()
    key = FileService.key_for_file(org_id=conv.org_id, message_id=msg.id, filename=file.filename or "file")
    await FileService.upload_bytes(key=key, data=data, content_type=file.content_type or "application/octet-stream")
    msg.s3_key = key
    await AuditService.log(
        db,
        user_id=user.id,
        action=AuditAction.FILE_UPLOADED,
        resource_type="message",
        resource_id=msg.id,
    )
    await db.commit()

    out = MessageService.to_out(msg)
    await ws_manager.broadcast_org(conv.org_id, WsEventServer.NEW_MESSAGE, out.model_dump(mode="json"))
    return out


@router.post("/voice-notes/{conversation_id}", response_model=MessageOut)
async def upload_voice_note(
    conversation_id: uuid.UUID,
    file: UploadFile,
    duration_sec: int = Form(default=0),
    transcript: str = Form(default=""),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    conv = await _assert_conv_member(conversation_id, user.id, db)
    data = await file.read()
    if len(data) > VOICE_NOTE_MAX_FILE_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="voice_note_too_large")

    client_transcript = transcript.strip() if transcript else ""

    msg = Message(
        conversation_id=conversation_id,
        sender_id=user.id,
        type=MessageType.VOICE_NOTE,
        file_name=file.filename,
        file_size_bytes=len(data),
        voice_duration_sec=duration_sec,
        transcript=client_transcript or None,
        transcript_status=TranscriptStatus.COMPLETED if client_transcript else TranscriptStatus.PENDING,
        expires_at=MessageService.expiry_for(conv),
    )
    db.add(msg)
    await db.flush()
    key = FileService.key_for_voice_note(org_id=conv.org_id, message_id=msg.id)
    content_type = file.content_type or "audio/wav"
    await FileService.upload_bytes(key=key, data=data, content_type=content_type)
    msg.s3_key = key
    await AuditService.log(
        db,
        user_id=user.id,
        action=AuditAction.FILE_UPLOADED,
        resource_type="message",
        resource_id=msg.id,
    )
    await db.commit()

    out = MessageService.to_out(msg)
    await ws_manager.broadcast_org(conv.org_id, WsEventServer.NEW_MESSAGE, out.model_dump(mode="json"))

    if not client_transcript:
        await TranscriptionService.start(message_id=str(msg.id), s3_key=key)
        server_transcript = await TranscriptionService.fetch(message_id=str(msg.id))
        if server_transcript:
            msg.transcript = server_transcript
            msg.transcript_status = TranscriptStatus.COMPLETED
            await db.commit()
            await ws_manager.broadcast_org(
                conv.org_id,
                WsEventServer.TRANSCRIPT_READY,
                {"message_id": str(msg.id), "transcript": server_transcript},
            )
    return MessageService.to_out(msg)


@router.post(ApiRoutes.MESSAGES_READ, response_model=OkResponse)
async def mark_read(
    message_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OkResponse:
    msg = await db.scalar(select(Message).where(Message.id == message_id))
    if msg is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="message_not_found")
    await _assert_conv_member(msg.conversation_id, user.id, db)
    await MessageService.mark_read(message_id=message_id, user_id=user.id, db=db)
    conv = await db.scalar(select(Conversation).where(Conversation.id == msg.conversation_id))
    if conv is not None:
        await ws_manager.broadcast_org(
            conv.org_id,
            WsEventServer.MESSAGE_READ,
            {
                "message_id": str(message_id),
                "conversation_id": str(msg.conversation_id),
                "user_id": str(user.id),
            },
        )
    return OkResponse()


@router.get(ApiRoutes.MESSAGES_FILE_URL, response_model=FileUrlOut)
async def get_file_url(
    message_id: uuid.UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FileUrlOut:
    msg = await db.scalar(select(Message).where(Message.id == message_id))
    if msg is None or not msg.s3_key:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="file_not_found")
    await _assert_conv_member(msg.conversation_id, user.id, db)
    url = await FileService.presigned_url(key=msg.s3_key)
    await AuditService.log(
        db,
        user_id=user.id,
        action=AuditAction.FILE_ACCESSED,
        resource_type="message",
        resource_id=message_id,
    )
    return FileUrlOut(url=url, expires_in=PRESIGNED_URL_TTL_SECONDS)
