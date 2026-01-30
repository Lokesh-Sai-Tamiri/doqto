"""
Socket.io server setup and management.
"""

import socketio
from typing import Optional, Dict, Set
from dataclasses import dataclass, field

from middleware.auth import verify_supabase_token, AuthUser


# Create Socket.io server
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
    logger=True,
    engineio_logger=False,
)


@dataclass
class UserConnection:
    """Represents a connected user."""
    user_id: str
    sid: str
    conversations: Set[str] = field(default_factory=set)


class SocketManager:
    """Manages Socket.io connections and user sessions."""

    # Map of session ID to user connection
    _connections: Dict[str, UserConnection] = {}

    # Map of user ID to set of session IDs (for multi-device support)
    _user_sessions: Dict[str, Set[str]] = {}

    @classmethod
    async def authenticate(cls, sid: str, auth: dict) -> Optional[AuthUser]:
        """
        Authenticate a socket connection.

        Args:
            sid: Socket session ID
            auth: Auth data from client (should contain 'token')

        Returns:
            AuthUser if authentication successful, None otherwise
        """
        token = auth.get("token") if auth else None

        if not token:
            return None

        try:
            user = await verify_supabase_token(token)
            return user
        except Exception:
            return None

    @classmethod
    def register_connection(cls, sid: str, user_id: str) -> UserConnection:
        """Register a new socket connection."""
        connection = UserConnection(user_id=user_id, sid=sid)
        cls._connections[sid] = connection

        # Track user's sessions
        if user_id not in cls._user_sessions:
            cls._user_sessions[user_id] = set()
        cls._user_sessions[user_id].add(sid)

        return connection

    @classmethod
    def unregister_connection(cls, sid: str) -> Optional[str]:
        """
        Unregister a socket connection.

        Returns:
            The user_id if found, None otherwise
        """
        connection = cls._connections.pop(sid, None)

        if connection:
            # Remove from user sessions
            if connection.user_id in cls._user_sessions:
                cls._user_sessions[connection.user_id].discard(sid)
                if not cls._user_sessions[connection.user_id]:
                    del cls._user_sessions[connection.user_id]

            return connection.user_id

        return None

    @classmethod
    def get_connection(cls, sid: str) -> Optional[UserConnection]:
        """Get connection by session ID."""
        return cls._connections.get(sid)

    @classmethod
    def get_user_sessions(cls, user_id: str) -> Set[str]:
        """Get all session IDs for a user."""
        return cls._user_sessions.get(user_id, set())

    @classmethod
    def is_user_online(cls, user_id: str) -> bool:
        """Check if a user has any active connections."""
        return user_id in cls._user_sessions and len(cls._user_sessions[user_id]) > 0

    @classmethod
    async def join_conversation(cls, sid: str, conversation_id: str) -> bool:
        """Join a user to a conversation room."""
        connection = cls._connections.get(sid)
        if connection:
            connection.conversations.add(conversation_id)
            room_name = f"conversation:{conversation_id}"
            await sio.enter_room(sid, room_name)
            print(f"✅ User {connection.user_id} (sid: {sid}) joined room {room_name}")
            return True
        print(f"❌ join_conversation failed: No connection for sid {sid}")
        return False

    @classmethod
    async def leave_conversation(cls, sid: str, conversation_id: str) -> bool:
        """Leave a conversation room."""
        connection = cls._connections.get(sid)
        if connection:
            connection.conversations.discard(conversation_id)
            await sio.leave_room(sid, f"conversation:{conversation_id}")
            return True
        return False

    @classmethod
    async def emit_to_user(cls, user_id: str, event: str, data: dict) -> int:
        """
        Emit an event to all sessions of a user.

        Returns:
            Number of sessions the event was sent to
        """
        sessions = cls.get_user_sessions(user_id)
        for sid in sessions:
            await sio.emit(event, data, to=sid)
        return len(sessions)

    @classmethod
    async def emit_to_conversation(
        cls,
        conversation_id: str,
        event: str,
        data: dict,
        exclude_sid: Optional[str] = None,
        exclude_user_id: Optional[str] = None
    ):
        """Emit an event to all users in a conversation room."""
        room_name = f"conversation:{conversation_id}"
        print(f"📤 emit_to_conversation: room={room_name}, event={event}, exclude_sid={exclude_sid}, exclude_user_id={exclude_user_id}")

        if exclude_user_id:
            # Get all sessions for the user to exclude
            user_sessions = cls.get_user_sessions(exclude_user_id)
            print(f"   Excluding user {exclude_user_id} sessions: {user_sessions}")

            # Simple approach: emit to room, skip the first session of excluded user
            skip = next(iter(user_sessions), None) if user_sessions else None
            await sio.emit(
                event,
                data,
                room=room_name,
                skip_sid=skip
            )
        else:
            await sio.emit(
                event,
                data,
                room=room_name,
                skip_sid=exclude_sid
            )
        print(f"✅ Event {event} emitted to room {room_name}")

    @classmethod
    def get_online_users(cls) -> Set[str]:
        """Get set of all online user IDs."""
        return set(cls._user_sessions.keys())

    @classmethod
    def get_connection_count(cls) -> int:
        """Get total number of active connections."""
        return len(cls._connections)
