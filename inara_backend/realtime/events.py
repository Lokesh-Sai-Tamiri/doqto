"""
Socket.io event handlers for real-time features.
"""

from typing import Optional
from realtime.socket_manager import sio, SocketManager
from services.messaging_service import MessagingService


async def _resolve_conversation_id(conversation_id: str, user_id: str) -> Optional[str]:
    """Resolve conversation_id which may be a user UUID or MongoDB ObjectId."""
    # Check if it looks like a UUID (user ID) vs ObjectId
    if '-' in conversation_id or len(conversation_id) != 24:
        # It's a user ID, find or create conversation
        conv = await MessagingService.get_or_create_conversation(user_id, conversation_id)
        return conv.id if conv else None
    return conversation_id


def register_events():
    """Register all Socket.io event handlers."""

    @sio.event
    async def connect(sid, environ, auth):
        """Handle new socket connection."""
        user = await SocketManager.authenticate(sid, auth)

        if not user:
            # Reject unauthenticated connections
            await sio.disconnect(sid)
            return False

        # Register the connection
        SocketManager.register_connection(sid, user.user_id)

        # Join user's personal room for direct notifications
        await sio.enter_room(sid, f"user:{user.user_id}")

        print(f"User {user.user_id} connected (sid: {sid})")
        return True

    @sio.event
    async def disconnect(sid):
        """Handle socket disconnection."""
        user_id = SocketManager.unregister_connection(sid)

        if user_id:
            print(f"User {user_id} disconnected (sid: {sid})")

            # If user has no more active sessions, broadcast offline status
            if not SocketManager.is_user_online(user_id):
                # Notify relevant users about offline status
                pass

    @sio.event
    async def join_conversations(sid, data):
        """Join user's conversation rooms for real-time updates."""
        connection = SocketManager.get_connection(sid)
        if not connection:
            return {"error": "Not authenticated"}

        # Get user's conversations and join rooms
        conversations = await MessagingService.get_conversations(connection.user_id)

        for conv in conversations:
            await SocketManager.join_conversation(sid, conv.id)

        return {"joined": len(conversations)}

    @sio.event
    async def join_conversation(sid, data):
        """Join a specific conversation room."""
        connection = SocketManager.get_connection(sid)
        if not connection:
            return {"error": "Not authenticated"}

        conversation_id = data.get("conversation_id")
        if not conversation_id:
            return {"error": "conversation_id required"}

        # Resolve conversation ID (might be user UUID or MongoDB ObjectId)
        actual_id = await _resolve_conversation_id(conversation_id, connection.user_id)
        if not actual_id:
            return {"error": "Conversation not found"}

        # Verify user is participant
        conv = await MessagingService.get_conversation(actual_id, connection.user_id)
        if not conv:
            return {"error": "Not a participant"}

        await SocketManager.join_conversation(sid, actual_id)
        return {"success": True, "conversation_id": actual_id}

    @sio.event
    async def leave_conversation(sid, data):
        """Leave a conversation room."""
        connection = SocketManager.get_connection(sid)
        if not connection:
            return {"error": "Not authenticated"}

        conversation_id = data.get("conversation_id")
        if conversation_id:
            await SocketManager.leave_conversation(sid, conversation_id)

        return {"success": True}

    @sio.event
    async def typing_start(sid, data):
        """Broadcast typing indicator start."""
        print(f"⌨️ typing_start received from {sid}: {data}")
        connection = SocketManager.get_connection(sid)
        if not connection:
            print("❌ typing_start: No connection found")
            return

        conversation_id = data.get("conversation_id")
        if not conversation_id:
            print("❌ typing_start: No conversation_id")
            return

        # Resolve conversation ID (might be user UUID)
        actual_id = await _resolve_conversation_id(conversation_id, connection.user_id)
        if not actual_id:
            print(f"❌ typing_start: Could not resolve conversation_id {conversation_id}")
            return

        print(f"✅ Broadcasting typing:start to conversation {actual_id}")
        await SocketManager.emit_to_conversation(
            actual_id,
            "typing:start",
            {
                "conversation_id": actual_id,
                "user_id": connection.user_id,
            },
            exclude_sid=sid
        )

    @sio.event
    async def typing_stop(sid, data):
        """Broadcast typing indicator stop."""
        print(f"⌨️ typing_stop received from {sid}: {data}")
        connection = SocketManager.get_connection(sid)
        if not connection:
            print("❌ typing_stop: No connection found")
            return

        conversation_id = data.get("conversation_id")
        if not conversation_id:
            print("❌ typing_stop: No conversation_id")
            return

        # Resolve conversation ID (might be user UUID)
        actual_id = await _resolve_conversation_id(conversation_id, connection.user_id)
        if not actual_id:
            print(f"❌ typing_stop: Could not resolve conversation_id {conversation_id}")
            return

        print(f"✅ Broadcasting typing:stop to conversation {actual_id}")
        await SocketManager.emit_to_conversation(
            actual_id,
            "typing:stop",
            {
                "conversation_id": actual_id,
                "user_id": connection.user_id,
            },
            exclude_sid=sid
        )

    @sio.event
    async def message_delivered(sid, data):
        """Handle message delivered acknowledgment."""
        connection = SocketManager.get_connection(sid)
        if not connection:
            return

        message_id = data.get("message_id")
        if not message_id:
            return

        # Update message status
        success = await MessagingService.mark_message_delivered(
            message_id,
            connection.user_id
        )

        if success:
            # Notify sender about delivery
            conversation_id = data.get("conversation_id")
            if conversation_id:
                await SocketManager.emit_to_conversation(
                    conversation_id,
                    "message:updated",
                    {
                        "message_id": message_id,
                        "status": "delivered",
                    },
                    exclude_sid=sid
                )

    @sio.event
    async def ping(sid, data):
        """Health check ping."""
        return {"pong": True}


# Event emitters for use by API endpoints

async def emit_new_message(conversation_id: str, message: dict, sender_id: str):
    """Emit new message event to conversation participants (excluding sender)."""
    await SocketManager.emit_to_conversation(
        conversation_id,
        "message:new",
        {
            "conversation_id": conversation_id,
            "message": message,
        },
        exclude_user_id=sender_id
    )


async def emit_message_updated(conversation_id: str, message_id: str, status: str):
    """Emit message status update."""
    await SocketManager.emit_to_conversation(
        conversation_id,
        "message:updated",
        {
            "message_id": message_id,
            "status": status,
        }
    )


async def emit_conversation_updated(conversation_id: str, data: dict):
    """Emit conversation update (settings, last message, etc.)."""
    await SocketManager.emit_to_conversation(
        conversation_id,
        "conversation:updated",
        {
            "conversation_id": conversation_id,
            **data,
        }
    )


async def emit_connection_request(recipient_id: str, request_data: dict):
    """Emit connection request notification to recipient."""
    await SocketManager.emit_to_user(
        recipient_id,
        "connection:request",
        request_data
    )


async def emit_connection_accepted(requester_id: str, connection_data: dict):
    """Emit connection accepted notification to requester."""
    await SocketManager.emit_to_user(
        requester_id,
        "connection:accepted",
        connection_data
    )


async def emit_messages_read(conversation_id: str, reader_id: str, message_ids: list):
    """Emit messages read event to conversation (so sender sees double tick)."""
    await SocketManager.emit_to_conversation(
        conversation_id,
        "messages:read",
        {
            "conversation_id": conversation_id,
            "reader_id": reader_id,
            "message_ids": message_ids,
        },
        exclude_user_id=reader_id
    )


# ==================== Group Events ====================

async def emit_group_created(group_id: str, group_data: dict, participant_ids: list):
    """Emit group created event to all participants."""
    for user_id in participant_ids:
        await SocketManager.emit_to_user(
            user_id,
            "group:created",
            {
                "group_id": group_id,
                "group": group_data,
            }
        )


async def emit_group_updated(group_id: str, group_data: dict, participant_ids: list):
    """Emit group info updated event to all participants."""
    await SocketManager.emit_to_conversation(
        group_id,
        "group:updated",
        {
            "group_id": group_id,
            "group": group_data,
        }
    )


async def emit_group_members_added(
    group_id: str,
    new_member_ids: list,
    group_data: dict,
    participant_ids: list
):
    """Emit members added event. Notify existing and new members."""
    # Notify existing members in the conversation room
    await SocketManager.emit_to_conversation(
        group_id,
        "group:members_added",
        {
            "group_id": group_id,
            "new_member_ids": new_member_ids,
            "group": group_data,
        }
    )

    # Notify new members directly (they might not be in the room yet)
    for member_id in new_member_ids:
        await SocketManager.emit_to_user(
            member_id,
            "group:created",  # Treat as new group for them
            {
                "group_id": group_id,
                "group": group_data,
            }
        )


async def emit_group_member_removed(
    group_id: str,
    removed_user_id: str,
    actor_id: str,
    participant_ids: list
):
    """Emit member removed event."""
    # Notify remaining members
    await SocketManager.emit_to_conversation(
        group_id,
        "group:member_removed",
        {
            "group_id": group_id,
            "removed_user_id": removed_user_id,
            "actor_id": actor_id,
        }
    )

    # Notify the removed user
    await SocketManager.emit_to_user(
        removed_user_id,
        "group:removed_from_group",
        {
            "group_id": group_id,
            "actor_id": actor_id,
        }
    )


async def emit_group_member_left(group_id: str, user_id: str, participant_ids: list):
    """Emit member left event."""
    await SocketManager.emit_to_conversation(
        group_id,
        "group:member_left",
        {
            "group_id": group_id,
            "user_id": user_id,
        }
    )


async def emit_group_admin_changed(
    group_id: str,
    user_id: str,
    is_admin: bool,
    participant_ids: list
):
    """Emit admin role changed event."""
    await SocketManager.emit_to_conversation(
        group_id,
        "group:admin_changed",
        {
            "group_id": group_id,
            "user_id": user_id,
            "is_admin": is_admin,
        }
    )
