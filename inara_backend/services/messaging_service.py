"""
Messaging service for conversations, messages, and preferences.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from bson import ObjectId

from db.collections import Collections
from api.models.messaging import (
    ConversationModel,
    ConversationSettings,
    ConversationSettingsEntry,
    MessageModel,
    MessageCreate,
    MessageType,
    MessageStatus,
    LastMessage,
    MessagingPreferencesModel,
    MessagingPreferencesUpdate,
    WhoCanMessage,
    NotificationSettings,
    UnreadCountResponse,
)
from services.profile_service import ProfileService


class MessagingService:
    """Service for messaging operations."""

    # ==================== Conversations ====================

    @staticmethod
    def _conversation_doc_to_model(doc: dict) -> ConversationModel:
        """Convert MongoDB document to ConversationModel."""
        settings = {}
        for user_id, user_settings in doc.get("settings", {}).items():
            settings[user_id] = ConversationSettingsEntry(**user_settings)

        last_msg = doc.get("last_message")
        last_message = None
        if last_msg:
            last_message = LastMessage(
                text=last_msg.get("text"),
                type=MessageType(last_msg.get("type", "text")),
                sender_id=last_msg.get("sender_id"),
                at=last_msg.get("at"),
            )

        return ConversationModel(
            id=str(doc["_id"]),
            participants=doc["participants"],
            settings=settings,
            last_message=last_message,
            unread_count=doc.get("unread_count", 0),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
            updated_at=doc.get("updated_at", datetime.now(timezone.utc)),
            other_user=doc.get("other_user"),
            is_blocked=doc.get("is_blocked", False),
            blocked_by_other=doc.get("blocked_by_other", False),
        )

    @staticmethod
    async def get_conversations(user_id: str) -> List[ConversationModel]:
        """Get all conversations for a user with other user profile info."""
        cursor = Collections.conversations().find(
            {"participants": user_id}
        ).sort("updated_at", -1)

        conversations = []
        async for doc in cursor:
            conv = MessagingService._conversation_doc_to_model(doc)

            # Get other user's profile
            other_user_id = [p for p in conv.participants if p != user_id][0]
            other_profile = await ProfileService.get_by_user_id(other_user_id)
            if other_profile:
                conv.other_user = {
                    "user_id": other_profile.user_id,
                    "display_name": other_profile.display_name,
                    "first_name": other_profile.first_name,
                    "last_name": other_profile.last_name,
                    "avatar_url": other_profile.avatar_url,
                    "specialization": other_profile.specialization,
                }

            # Check block status
            blocked = await Collections.blocked_users().find_one({
                "blocker_id": user_id,
                "blocked_id": other_user_id
            })
            conv.is_blocked = blocked is not None

            blocked_by = await Collections.blocked_users().find_one({
                "blocker_id": other_user_id,
                "blocked_id": user_id
            })
            conv.blocked_by_other = blocked_by is not None

            # Calculate unread count
            unread = await Collections.messages().count_documents({
                "conversation_id": ObjectId(conv.id),
                "sender_id": {"$ne": user_id},
                "read_at": None
            })
            conv.unread_count = unread

            conversations.append(conv)

        return conversations

    @staticmethod
    async def get_or_create_conversation(user_id: str, other_user_id: str) -> ConversationModel:
        """Get existing conversation or create new one."""
        # Check for existing conversation
        existing = await Collections.conversations().find_one({
            "participants": {"$all": [user_id, other_user_id], "$size": 2}
        })

        if existing:
            conv = MessagingService._conversation_doc_to_model(existing)
            # Populate other user info
            conv = await MessagingService._populate_other_user(conv, user_id)
            return conv

        # Create new conversation
        now = datetime.now(timezone.utc)
        doc = {
            "participants": sorted([user_id, other_user_id]),
            "settings": {
                user_id: {"is_muted": False, "is_archived": False, "is_pinned": False},
                other_user_id: {"is_muted": False, "is_archived": False, "is_pinned": False},
            },
            "last_message": None,
            "created_at": now,
            "updated_at": now,
        }

        result = await Collections.conversations().insert_one(doc)
        doc["_id"] = result.inserted_id

        conv = MessagingService._conversation_doc_to_model(doc)
        # Populate other user info
        conv = await MessagingService._populate_other_user(conv, user_id)
        return conv

    @staticmethod
    async def _populate_other_user(conv: ConversationModel, user_id: str) -> ConversationModel:
        """Populate other user profile info on a conversation."""
        other_user_id = [p for p in conv.participants if p != user_id][0]
        other_profile = await ProfileService.get_by_user_id(other_user_id)
        if other_profile:
            conv.other_user = {
                "user_id": other_profile.user_id,
                "display_name": other_profile.display_name,
                "first_name": other_profile.first_name,
                "last_name": other_profile.last_name,
                "avatar_url": other_profile.avatar_url,
                "specialization": other_profile.specialization,
            }
        return conv

    @staticmethod
    async def get_conversation(conversation_id: str, user_id: str) -> Optional[ConversationModel]:
        """Get a specific conversation if user is a participant."""
        try:
            doc = await Collections.conversations().find_one({
                "_id": ObjectId(conversation_id),
                "participants": user_id
            })
            if doc:
                conv = MessagingService._conversation_doc_to_model(doc)
                # Populate other user info
                conv = await MessagingService._populate_other_user(conv, user_id)
                return conv
        except Exception:
            pass
        return None

    @staticmethod
    async def update_conversation_settings(
        conversation_id: str,
        user_id: str,
        settings: ConversationSettings
    ) -> Optional[ConversationModel]:
        """Update user's settings for a conversation."""
        update_data = {}
        for field, value in settings.model_dump(exclude_unset=True).items():
            update_data[f"settings.{user_id}.{field}"] = value

        update_data["updated_at"] = datetime.now(timezone.utc)

        try:
            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id), "participants": user_id},
                {"$set": update_data},
                return_document=True,
            )
            if result:
                return MessagingService._conversation_doc_to_model(result)
        except Exception:
            pass
        return None

    @staticmethod
    async def delete_conversation(conversation_id: str, user_id: str) -> bool:
        """Soft delete conversation for a user (archive it)."""
        try:
            result = await Collections.conversations().update_one(
                {"_id": ObjectId(conversation_id), "participants": user_id},
                {"$set": {f"settings.{user_id}.is_archived": True}}
            )
            return result.modified_count > 0
        except Exception:
            return False

    # ==================== Messages ====================

    @staticmethod
    def _message_doc_to_model(doc: dict) -> MessageModel:
        """Convert MongoDB document to MessageModel."""
        return MessageModel(
            id=str(doc["_id"]),
            conversation_id=str(doc["conversation_id"]),
            sender_id=doc["sender_id"],
            message_type=MessageType(doc.get("message_type", "text")),
            content=doc.get("content"),
            file=doc.get("file"),
            audio=doc.get("audio"),
            saved_by=doc.get("saved_by"),
            saved_at=doc.get("saved_at"),
            status=MessageStatus(doc.get("status", "sent")),
            delivered_at=doc.get("delivered_at"),
            read_at=doc.get("read_at"),
            disappears_at=doc.get("disappears_at"),
            reply_to_id=str(doc["reply_to_id"]) if doc.get("reply_to_id") else None,
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
        )

    @staticmethod
    async def get_messages(
        conversation_id: str,
        user_id: str,
        limit: int = 50,
        before: Optional[str] = None
    ) -> List[MessageModel]:
        """Get messages for a conversation with pagination."""
        # Verify user is participant
        conv = await MessagingService.get_conversation(conversation_id, user_id)
        if not conv:
            return []

        query: Dict[str, Any] = {"conversation_id": ObjectId(conversation_id)}

        if before:
            try:
                query["_id"] = {"$lt": ObjectId(before)}
            except Exception:
                pass

        cursor = Collections.messages().find(query).sort("created_at", -1).limit(limit)

        messages = []
        async for doc in cursor:
            msg = MessagingService._message_doc_to_model(doc)

            # Fetch reply_to message if exists
            if msg.reply_to_id:
                try:
                    reply_doc = await Collections.messages().find_one(
                        {"_id": ObjectId(msg.reply_to_id)}
                    )
                    if reply_doc:
                        msg.reply_to = MessagingService._message_doc_to_model(reply_doc)
                except Exception:
                    pass

            messages.append(msg)

        # Return in reverse chronological order (newest first)
        # This works with reverse:true ListView in Flutter
        return messages

    @staticmethod
    async def send_message(
        conversation_id: str,
        sender_id: str,
        data: MessageCreate
    ) -> Optional[MessageModel]:
        """Send a new message."""
        # Verify sender is participant
        conv = await MessagingService.get_conversation(conversation_id, sender_id)
        if not conv:
            return None

        now = datetime.now(timezone.utc)

        # Calculate disappears_at if conversation has disappearing messages
        disappears_at = None
        sender_settings = conv.settings.get(sender_id)
        if sender_settings and sender_settings.disappearing_hours:
            disappears_at = now + timedelta(hours=sender_settings.disappearing_hours)

        doc = {
            "conversation_id": ObjectId(conversation_id),
            "sender_id": sender_id,
            "message_type": data.message_type.value,
            "content": data.content,
            "file": data.file.model_dump() if data.file else None,
            "audio": data.audio.model_dump() if data.audio else None,
            "status": MessageStatus.SENT.value,
            "disappears_at": disappears_at,
            "reply_to_id": ObjectId(data.reply_to_id) if data.reply_to_id else None,
            "created_at": now,
        }

        result = await Collections.messages().insert_one(doc)
        doc["_id"] = result.inserted_id

        # Update conversation's last message
        last_message_text = data.content
        if data.message_type == MessageType.AUDIO:
            last_message_text = "Audio message"
        elif data.message_type == MessageType.IMAGE:
            last_message_text = "Image"
        elif data.message_type == MessageType.DOCUMENT:
            last_message_text = data.file.name if data.file else "Document"

        await Collections.conversations().update_one(
            {"_id": ObjectId(conversation_id)},
            {
                "$set": {
                    "last_message": {
                        "text": last_message_text,
                        "type": data.message_type.value,
                        "sender_id": sender_id,
                        "at": now,
                    },
                    "updated_at": now,
                }
            }
        )

        return MessagingService._message_doc_to_model(doc)

    @staticmethod
    async def mark_messages_read(conversation_id: str, user_id: str) -> tuple[int, List[str]]:
        """Mark all messages from other users as read.

        Returns:
            Tuple of (count of messages marked, list of message IDs)
        """
        now = datetime.now(timezone.utc)

        # First, find the messages that will be marked read
        cursor = Collections.messages().find(
            {
                "conversation_id": ObjectId(conversation_id),
                "sender_id": {"$ne": user_id},
                "read_at": None,
            },
            {"_id": 1}
        )
        message_ids = [str(doc["_id"]) async for doc in cursor]

        if not message_ids:
            return 0, []

        # Update the messages
        result = await Collections.messages().update_many(
            {
                "conversation_id": ObjectId(conversation_id),
                "sender_id": {"$ne": user_id},
                "read_at": None,
            },
            {
                "$set": {
                    "status": MessageStatus.READ.value,
                    "read_at": now,
                }
            }
        )

        return result.modified_count, message_ids

    @staticmethod
    async def mark_message_delivered(message_id: str, user_id: str) -> bool:
        """Mark a message as delivered."""
        try:
            result = await Collections.messages().update_one(
                {
                    "_id": ObjectId(message_id),
                    "sender_id": {"$ne": user_id},
                    "delivered_at": None,
                },
                {
                    "$set": {
                        "status": MessageStatus.DELIVERED.value,
                        "delivered_at": datetime.now(timezone.utc),
                    }
                }
            )
            return result.modified_count > 0
        except Exception:
            return False

    @staticmethod
    async def save_audio_message(message_id: str, user_id: str) -> Optional[MessageModel]:
        """Save an audio message (allow user to keep it)."""
        try:
            result = await Collections.messages().find_one_and_update(
                {
                    "_id": ObjectId(message_id),
                    "message_type": MessageType.AUDIO.value,
                },
                {
                    "$set": {
                        "saved_by": user_id,
                        "saved_at": datetime.now(timezone.utc),
                        "disappears_at": None,  # Remove auto-delete
                    }
                },
                return_document=True,
            )
            if result:
                return MessagingService._message_doc_to_model(result)
        except Exception:
            pass
        return None

    # ==================== Preferences ====================

    @staticmethod
    def _preferences_doc_to_model(doc: dict) -> MessagingPreferencesModel:
        """Convert MongoDB document to MessagingPreferencesModel."""
        notifications = doc.get("notifications", {})
        return MessagingPreferencesModel(
            id=str(doc["_id"]),
            user_id=doc["user_id"],
            who_can_message=WhoCanMessage(doc.get("who_can_message", "everyone")),
            read_receipts_enabled=doc.get("read_receipts_enabled", True),
            show_typing_indicator=doc.get("show_typing_indicator", True),
            show_online_status=doc.get("show_online_status", True),
            allow_audio_save=doc.get("allow_audio_save", False),
            default_disappearing_hours=doc.get("default_disappearing_hours"),
            notifications=NotificationSettings(
                enabled=notifications.get("enabled", True),
                sound=notifications.get("sound", True),
                vibration=notifications.get("vibration", True),
            ),
        )

    @staticmethod
    async def get_preferences(user_id: str) -> MessagingPreferencesModel:
        """Get messaging preferences, creating defaults if not exists."""
        doc = await Collections.messaging_preferences().find_one({"user_id": user_id})

        if doc:
            return MessagingService._preferences_doc_to_model(doc)

        # Create default preferences
        now = datetime.now(timezone.utc)
        default_doc = {
            "user_id": user_id,
            "who_can_message": WhoCanMessage.EVERYONE.value,
            "read_receipts_enabled": True,
            "show_typing_indicator": True,
            "show_online_status": True,
            "allow_audio_save": False,
            "default_disappearing_hours": None,
            "notifications": {
                "enabled": True,
                "sound": True,
                "vibration": True,
            },
            "created_at": now,
        }

        result = await Collections.messaging_preferences().insert_one(default_doc)
        default_doc["_id"] = result.inserted_id

        return MessagingService._preferences_doc_to_model(default_doc)

    @staticmethod
    async def update_preferences(
        user_id: str,
        data: MessagingPreferencesUpdate
    ) -> MessagingPreferencesModel:
        """Update messaging preferences."""
        update_data = {}

        for field, value in data.model_dump(exclude_unset=True).items():
            if field == "who_can_message" and value:
                update_data["who_can_message"] = value.value
            elif field == "notifications" and value:
                update_data["notifications"] = value.model_dump()
            else:
                update_data[field] = value

        if update_data:
            await Collections.messaging_preferences().update_one(
                {"user_id": user_id},
                {"$set": update_data},
                upsert=True,
            )

        return await MessagingService.get_preferences(user_id)

    @staticmethod
    async def get_unread_count(user_id: str) -> UnreadCountResponse:
        """Get total unread message count and per-conversation breakdown."""
        # Get all conversations
        conversations = await MessagingService.get_conversations(user_id)

        by_conversation = {}
        total = 0

        for conv in conversations:
            if conv.unread_count > 0:
                by_conversation[conv.id] = conv.unread_count
                total += conv.unread_count

        return UnreadCountResponse(
            total_unread=total,
            by_conversation=by_conversation,
        )
