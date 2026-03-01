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
    GroupCreate,
    GroupUpdate,
    GroupMembersAdd,
    GroupAdminUpdate,
)
from services.messaging_service import MessagingService
from services.storage_service import StorageService
from services.connection_service import ConnectionService
from services.audit_service import AuditService
from realtime.events import (
    emit_new_message,
    emit_messages_read,
    emit_group_created,
    emit_group_updated,
    emit_group_members_added,
    emit_group_member_removed,
    emit_group_member_left,
    emit_group_admin_changed,
)

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


# ==================== Groups ====================

@router.post("/groups", response_model=ConversationModel)
async def create_group(
    data: GroupCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Create a new group conversation."""
    conv = await MessagingService.create_group(
        creator_id=user.user_id,
        name=data.name,
        participant_ids=data.participant_ids,
        description=data.description
    )

    # Emit real-time event to all participants
    await emit_group_created(
        conv.id,
        conv.model_dump(mode='json'),
        conv.participants
    )

    return conv


@router.patch("/groups/{group_id}", response_model=ConversationModel)
async def update_group(
    group_id: str,
    data: GroupUpdate,
    user: AuthUser = Depends(get_current_user)
):
    """Update group information."""
    conv = await MessagingService.update_group_info(
        conversation_id=group_id,
        user_id=user.user_id,
        name=data.name,
        description=data.description,
        icon_url=data.icon_url,
        settings=data.settings
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot update this group"
        )

    # Emit real-time event
    await emit_group_updated(
        group_id,
        conv.model_dump(mode='json'),
        conv.participants
    )

    return conv


@router.post("/groups/{group_id}/members", response_model=ConversationModel)
async def add_group_members(
    group_id: str,
    data: GroupMembersAdd,
    user: AuthUser = Depends(get_current_user)
):
    """Add members to a group."""
    conv = await MessagingService.add_group_members(
        conversation_id=group_id,
        actor_id=user.user_id,
        user_ids=data.user_ids
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot add members to this group"
        )

    # Emit real-time event
    await emit_group_members_added(
        group_id,
        data.user_ids,
        conv.model_dump(mode='json'),
        conv.participants
    )

    return conv


@router.delete("/groups/{group_id}/members/{member_id}")
async def remove_group_member(
    group_id: str,
    member_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Remove a member from a group (admin only)."""
    conv = await MessagingService.remove_group_member(
        conversation_id=group_id,
        actor_id=user.user_id,
        user_id=member_id
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot remove this member"
        )

    # Emit real-time event
    await emit_group_member_removed(
        group_id,
        member_id,
        user.user_id,
        conv.participants + [member_id]  # Include removed member
    )

    return {"success": True}


@router.post("/groups/{group_id}/leave")
async def leave_group(
    group_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Leave a group conversation."""
    # Get participants before leaving
    conv = await MessagingService.get_conversation(group_id, user.user_id)
    if not conv:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found"
        )

    success = await MessagingService.leave_group(
        conversation_id=group_id,
        user_id=user.user_id
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot leave this group"
        )

    # Emit real-time event
    await emit_group_member_left(
        group_id,
        user.user_id,
        conv.participants  # Includes the leaving user
    )

    return {"success": True}


@router.post("/groups/{group_id}/admins", response_model=ConversationModel)
async def add_group_admin(
    group_id: str,
    data: GroupAdminUpdate,
    user: AuthUser = Depends(get_current_user)
):
    """Promote a group member to admin."""
    conv = await MessagingService.add_group_admin(
        conversation_id=group_id,
        actor_id=user.user_id,
        user_id=data.user_id
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot promote this member"
        )

    # Emit real-time event
    await emit_group_admin_changed(
        group_id,
        data.user_id,
        True,  # is_admin now
        conv.participants
    )

    return conv


@router.delete("/groups/{group_id}/admins/{admin_id}", response_model=ConversationModel)
async def remove_group_admin(
    group_id: str,
    admin_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Demote a group admin."""
    conv = await MessagingService.remove_group_admin(
        conversation_id=group_id,
        actor_id=user.user_id,
        user_id=admin_id
    )

    if not conv:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot demote this admin"
        )

    # Emit real-time event
    await emit_group_admin_changed(
        group_id,
        admin_id,
        False,  # is_admin now
        conv.participants
    )

    return conv


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
    
    # Audit log: User accessed PHI
    await AuditService.log_phi_access(
        user_id=user.user_id,
        resource_type="conversation",
        target_id=actual_id,
        action="read_messages",
        metadata={"limit": limit, "count": len(messages)}
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

    # Audit log: User created PHI
    await AuditService.log_phi_access(
        user_id=user.user_id,
        resource_type="message",
        target_id=message.id,
        action="send",
        metadata={
            "conversation_id": actual_conversation_id,
            "message_type": message.message_type.value
        }
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
