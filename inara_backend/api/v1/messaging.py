"""
Messaging API endpoints for conversations, messages, and preferences.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional, List

from middleware.auth import get_current_user, AuthUser
from api.models.messaging import (
    ConversationModel,
    ConversationCreate,
    ConversationSettings,
    MessageModel,
    MessageCreate,
    MessagingPreferencesModel,
    MessagingPreferencesUpdate,
    UnreadCountResponse,
)
from services.messaging_service import MessagingService
from services.storage_service import StorageService
from services.connection_service import ConnectionService
from realtime.events import emit_new_message, emit_messages_read

router = APIRouter()


# ==================== Conversations ====================

@router.get("/conversations", response_model=List[ConversationModel])
async def list_conversations(user: AuthUser = Depends(get_current_user)):
    """Get all conversations for the current user."""
    return await MessagingService.get_conversations(user.user_id)


@router.post("/conversations", response_model=ConversationModel)
async def create_conversation(
    data: ConversationCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Create or get a conversation with another user."""
    # Check if blocked
    if await ConnectionService.is_blocked(user.user_id, data.other_user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create conversation with this user"
        )

    return await MessagingService.get_or_create_conversation(
        user.user_id,
        data.other_user_id
    )


@router.get("/conversations/{conversation_id}", response_model=ConversationModel)
async def get_conversation(
    conversation_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get a specific conversation."""
    actual_id = await _resolve_conversation_id(conversation_id, user.user_id)
    if not actual_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    conv = await MessagingService.get_conversation(actual_id, user.user_id)

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    return conv


@router.patch("/conversations/{conversation_id}/settings", response_model=ConversationModel)
async def update_conversation_settings(
    conversation_id: str,
    settings: ConversationSettings,
    user: AuthUser = Depends(get_current_user)
):
    """Update conversation settings (mute, archive, pin)."""
    actual_id = await _resolve_conversation_id(conversation_id, user.user_id)
    if not actual_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    conv = await MessagingService.update_conversation_settings(
        actual_id,
        user.user_id,
        settings
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    return conv


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Soft delete (archive) a conversation."""
    actual_id = await _resolve_conversation_id(conversation_id, user.user_id)
    if not actual_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    success = await MessagingService.delete_conversation(actual_id, user.user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )

    return {"success": True}


# ==================== Messages ====================

async def _resolve_conversation_id(conversation_id: str, user_id: str) -> Optional[str]:
    """Resolve conversation_id which may be a user UUID or MongoDB ObjectId."""
    # Check if it looks like a UUID (user ID) vs ObjectId
    if '-' in conversation_id or len(conversation_id) != 24:
        # It's a user ID, find existing conversation
        conv = await MessagingService.get_or_create_conversation(user_id, conversation_id)
        return conv.id if conv else None
    return conversation_id


@router.get("/conversations/{conversation_id}/messages", response_model=List[MessageModel])
async def get_messages(
    conversation_id: str,
    limit: int = Query(50, ge=1, le=100),
    before: Optional[str] = None,
    user: AuthUser = Depends(get_current_user)
):
    """Get messages for a conversation with pagination."""
    actual_id = await _resolve_conversation_id(conversation_id, user.user_id)
    if not actual_id:
        return []

    messages = await MessagingService.get_messages(
        actual_id,
        user.user_id,
        limit,
        before
    )

    return messages


@router.post("/conversations/{conversation_id}/messages", response_model=MessageModel)
async def send_message(
    conversation_id: str,
    data: MessageCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Send a new message.

    conversation_id can be either:
    - A MongoDB ObjectId (actual conversation ID)
    - A user UUID (other user's ID) - will auto-create/get conversation
    """
    actual_conversation_id = conversation_id

    # Check if conversation_id looks like a UUID (user ID) vs ObjectId
    # UUIDs have dashes, ObjectIds are 24 hex characters
    if '-' in conversation_id or len(conversation_id) != 24:
        # It's likely a user ID, get or create conversation
        other_user_id = conversation_id

        # Check if blocked
        if await ConnectionService.is_blocked(user.user_id, other_user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot send message to this user"
            )

        # Get or create conversation with this user
        conv = await MessagingService.get_or_create_conversation(
            user.user_id,
            other_user_id
        )
        actual_conversation_id = conv.id

    message = await MessagingService.send_message(
        actual_conversation_id,
        user.user_id,
        data
    )

    if not message:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot send message to this conversation"
        )

    # Emit real-time event to conversation participants
    await emit_new_message(
        actual_conversation_id,
        message.model_dump(mode='json'),
        user.user_id
    )

    return message


@router.post("/conversations/{conversation_id}/messages/read")
async def mark_messages_read(
    conversation_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Mark all messages in a conversation as read."""
    actual_id = await _resolve_conversation_id(conversation_id, user.user_id)
    if not actual_id:
        return {"marked_read": 0}

    count, message_ids = await MessagingService.mark_messages_read(actual_id, user.user_id)

    # Emit read receipt via Socket.io so sender sees double tick
    if count > 0 and message_ids:
        await emit_messages_read(actual_id, user.user_id, message_ids)

    return {"marked_read": count}


@router.post("/messages/{message_id}/save-audio", response_model=MessageModel)
async def save_audio_message(
    message_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Save an audio message (prevent auto-deletion)."""
    message = await MessagingService.save_audio_message(message_id, user.user_id)

    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio message not found"
        )

    return message


@router.post("/messages/{message_id}/delivered")
async def mark_message_delivered(
    message_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Mark a message as delivered."""
    success = await MessagingService.mark_message_delivered(message_id, user.user_id)
    return {"success": success}


# ==================== Preferences ====================

@router.get("/messaging/preferences", response_model=MessagingPreferencesModel)
async def get_preferences(user: AuthUser = Depends(get_current_user)):
    """Get messaging preferences for the current user."""
    return await MessagingService.get_preferences(user.user_id)


@router.put("/messaging/preferences", response_model=MessagingPreferencesModel)
async def update_preferences(
    data: MessagingPreferencesUpdate,
    user: AuthUser = Depends(get_current_user)
):
    """Update messaging preferences."""
    return await MessagingService.update_preferences(user.user_id, data)


@router.get("/messaging/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(user: AuthUser = Depends(get_current_user)):
    """Get total unread message count."""
    return await MessagingService.get_unread_count(user.user_id)


# ==================== File Uploads ====================

@router.post("/messaging/upload-url")
async def get_attachment_upload_url(
    filename: str,
    content_type: Optional[str] = None,
    user: AuthUser = Depends(get_current_user)
):
    """Get a presigned URL for uploading a message attachment."""
    try:
        upload_url, key, download_url = StorageService.get_attachment_upload_url(
            user.user_id,
            filename,
            content_type
        )

        return {
            "upload_url": upload_url,
            "key": key,
            "download_url": download_url,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate upload URL: {str(e)}"
        )
