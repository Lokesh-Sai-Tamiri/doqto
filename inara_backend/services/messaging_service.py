"""
Messaging service for conversations, messages, and preferences.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from bson import ObjectId

from db.collections import Collections
from api.models.messaging import (
    ConversationModel,
    ConversationType,
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
    GroupInfo,
    GroupSettings,
    GroupCreate,
    GroupUpdate,
    SystemEventType,
    SystemEventData,
)
from services.profile_service import ProfileService
from services.encryption_service import EncryptionService
from services.storage_service import StorageService


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

        # Parse group info if present
        group_info = None
        group_info_doc = doc.get("group_info")
        if group_info_doc:
            group_settings = GroupSettings(**group_info_doc.get("settings", {}))
            group_info = GroupInfo(
                name=group_info_doc.get("name", "Group"),
                icon_url=group_info_doc.get("icon_url"),
                description=group_info_doc.get("description"),
                created_by=group_info_doc.get("created_by", ""),
                admins=group_info_doc.get("admins", []),
                settings=group_settings,
            )

        conv_type = ConversationType(doc.get("type", "direct"))

        return ConversationModel(
            id=str(doc["_id"]),
            type=conv_type,
            participants=doc["participants"],
            settings=settings,
            last_message=last_message,
            unread_count=doc.get("unread_count", 0),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
            updated_at=doc.get("updated_at", datetime.now(timezone.utc)),
            group_info=group_info,
            other_user=doc.get("other_user"),
            member_profiles=doc.get("member_profiles", []),
            is_blocked=doc.get("is_blocked", False),
            blocked_by_other=doc.get("blocked_by_other", False),
        )

    @staticmethod
    async def get_conversations(user_id: str) -> List[ConversationModel]:
        """Get all conversations for a user with other user/member profile info."""
        cursor = Collections.conversations().find(
            {"participants": user_id}
        ).sort("updated_at", -1)

        conversations = []
        async for doc in cursor:
            conv = MessagingService._conversation_doc_to_model(doc)

            if conv.type == ConversationType.GROUP:
                # For group conversations, populate member profiles
                member_profiles = []
                for participant_id in conv.participants:
                    profile = await ProfileService.get_by_user_id(participant_id)
                    if profile:
                        is_admin = conv.group_info and participant_id in conv.group_info.admins
                        member_profiles.append({
                            "user_id": profile.user_id,
                            "display_name": profile.display_name,
                            "first_name": profile.first_name,
                            "last_name": profile.last_name,
                            "avatar_url": profile.avatar_url,
                            "is_admin": is_admin,
                        })
                conv.member_profiles = member_profiles
            else:
                # For direct conversations, get other user's profile
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

                # Check block status (only for direct conversations)
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
    async def _populate_conversation_profiles(conv: ConversationModel, user_id: str) -> ConversationModel:
        """Populate user profile info on a conversation (other user or members)."""
        if conv.type == ConversationType.GROUP:
            # For group conversations, populate member profiles
            member_profiles = []
            for participant_id in conv.participants:
                profile = await ProfileService.get_by_user_id(participant_id)
                if profile:
                    is_admin = conv.group_info and participant_id in conv.group_info.admins
                    member_profiles.append({
                        "user_id": profile.user_id,
                        "display_name": profile.display_name,
                        "first_name": profile.first_name,
                        "last_name": profile.last_name,
                        "avatar_url": profile.avatar_url,
                        "is_admin": is_admin,
                    })
            conv.member_profiles = member_profiles
        else:
            # For direct conversations, get other user's profile
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
    async def _populate_other_user(conv: ConversationModel, user_id: str) -> ConversationModel:
        """Populate other user profile info on a conversation (alias for backwards compatibility)."""
        return await MessagingService._populate_conversation_profiles(conv, user_id)

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
        # Get current conversation to check for changes
        conv_doc = await Collections.conversations().find_one(
            {"_id": ObjectId(conversation_id), "participants": user_id}
        )

        if not conv_doc:
            return None

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
                conv_model = MessagingService._conversation_doc_to_model(result)

                # Create system message for disappearing messages change
                if settings.disappearing_hours is not None:
                    old_hours = conv_doc.get("settings", {}).get(user_id, {}).get("disappearing_hours")
                    new_hours = settings.disappearing_hours

                    # Only create message if value actually changed
                    if old_hours != new_hours:
                        # Create system message
                        await MessagingService._create_disappearing_message_system_event(
                            conversation_id=conversation_id,
                            actor_id=user_id,
                            old_hours=old_hours,
                            new_hours=new_hours,
                        )

                return conv_model
        except Exception as e:
            print(f"Error updating conversation settings: {e}")
            pass
        return None

    @staticmethod
    async def _create_disappearing_message_system_event(
        conversation_id: str,
        actor_id: str,
        old_hours: Optional[int],
        new_hours: Optional[int],
    ):
        """Create a system message for disappearing message settings change."""
        # Format message text
        if new_hours is None:
            content = "{user:" + actor_id + "} turned off disappearing messages"
        elif new_hours == 1:
            content = "{user:" + actor_id + "} set messages to disappear after 1 hour"
        elif new_hours == 24:
            content = "{user:" + actor_id + "} set messages to disappear after 24 hours"
        elif new_hours == 168:
            content = "{user:" + actor_id + "} set messages to disappear after 1 week"
        else:
            content = f"{{user:{actor_id}}} set messages to disappear after {new_hours} hours"

        # Create system message
        message_doc = {
            "conversation_id": ObjectId(conversation_id),
            "sender_id": actor_id,
            "message_type": "system",
            "content": content,
            "system_event": {
                "event_type": "disappearing_changed",
                "actor_id": actor_id,
                "old_value": str(old_hours) if old_hours else None,
                "new_value": str(new_hours) if new_hours else None,
            },
            "status": "sent",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
        }

        result = await Collections.messages().insert_one(message_doc)
        message_doc["_id"] = result.inserted_id

        # Emit new message event to all participants
        from realtime.events import emit_new_message
        message_model = MessagingService._message_doc_to_model(message_doc)
        await emit_new_message(
            conversation_id,
            message_model.model_dump(mode="json"),
            sender_id=actor_id
        )

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
        # Parse system event if present
        system_event = None
        system_event_doc = doc.get("system_event")
        if system_event_doc:
            system_event = SystemEventData(
                event_type=SystemEventType(system_event_doc.get("event_type")),
                actor_id=system_event_doc.get("actor_id", ""),
                target_ids=system_event_doc.get("target_ids", []),
                old_value=system_event_doc.get("old_value"),
                new_value=system_event_doc.get("new_value"),
            )

        content = doc.get("content")
        if doc.get("content_encrypted") and content:
            content = EncryptionService.decrypt(content)

        return MessageModel(
            id=str(doc["_id"]),
            conversation_id=str(doc["conversation_id"]),
            sender_id=doc["sender_id"],
            message_type=MessageType(doc.get("message_type", "text")),
            content=content,
            file=doc.get("file"),
            audio=doc.get("audio"),
            saved_by=doc.get("saved_by"),
            saved_at=doc.get("saved_at"),
            status=MessageStatus(doc.get("status", "sent")),
            delivered_at=doc.get("delivered_at"),
            read_at=doc.get("read_at"),
            disappears_at=doc.get("disappears_at"),
            reply_to_id=str(doc["reply_to_id"]) if doc.get("reply_to_id") else None,
            mentions=doc.get("mentions", []),
            system_event=system_event,
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

        # For group conversations, check if only admins can send
        if conv.type == ConversationType.GROUP and conv.group_info:
            if conv.group_info.settings.only_admins_can_send:
                if sender_id not in conv.group_info.admins:
                    return None  # Non-admin cannot send in this group

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
            "content": EncryptionService.encrypt(data.content),
            "content_encrypted": True if data.content else False,
            "file": data.file.model_dump() if data.file else None,
            "audio": data.audio.model_dump() if data.audio else None,
            "status": MessageStatus.SENT.value,
            "disappears_at": disappears_at,
            "reply_to_id": ObjectId(data.reply_to_id) if data.reply_to_id else None,
            "mentions": data.mentions,
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

    # ==================== Groups ====================

    @staticmethod
    async def create_group(
        creator_id: str,
        name: str,
        participant_ids: List[str],
        description: Optional[str] = None
    ) -> ConversationModel:
        """Create a new group conversation."""
        now = datetime.now(timezone.utc)

        # Ensure creator is in participants
        all_participants = list(set([creator_id] + participant_ids))

        # Create settings for all participants
        settings = {}
        for user_id in all_participants:
            settings[user_id] = {"is_muted": False, "is_archived": False, "is_pinned": False}

        doc = {
            "type": ConversationType.GROUP.value,
            "participants": all_participants,
            "settings": settings,
            "group_info": {
                "name": name,
                "description": description,
                "icon_url": None,
                "created_by": creator_id,
                "admins": [creator_id],
                "settings": {
                    "only_admins_can_send": False,
                    "only_admins_can_edit_info": True,
                    "allow_member_invites": False,
                },
            },
            "last_message": None,
            "created_at": now,
            "updated_at": now,
        }

        result = await Collections.conversations().insert_one(doc)
        doc["_id"] = result.inserted_id

        conv = MessagingService._conversation_doc_to_model(doc)

        # Create system message for group creation
        await MessagingService._create_system_message(
            str(result.inserted_id),
            SystemEventType.GROUP_CREATED,
            creator_id,
            []
        )

        # Populate member profiles
        return await MessagingService._populate_conversation_profiles(conv, creator_id)

    @staticmethod
    async def update_group_info(
        conversation_id: str,
        user_id: str,
        name: Optional[str] = None,
        description: Optional[str] = None,
        icon_url: Optional[str] = None,
        settings: Optional[GroupSettings] = None
    ) -> Optional[ConversationModel]:
        """Update group information."""
        conv = await MessagingService.get_conversation(conversation_id, user_id)
        if not conv or conv.type != ConversationType.GROUP:
            return None

        # Check permissions
        if conv.group_info and conv.group_info.settings.only_admins_can_edit_info:
            if user_id not in conv.group_info.admins:
                return None

        update_data: Dict[str, Any] = {"updated_at": datetime.now(timezone.utc)}
        old_name = conv.group_info.name if conv.group_info else None

        if name is not None:
            update_data["group_info.name"] = name
        if description is not None:
            update_data["group_info.description"] = description
        if icon_url is not None:
            update_data["group_info.icon_url"] = icon_url
        if settings is not None:
            update_data["group_info.settings"] = settings.model_dump()

        try:
            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id)},
                {"$set": update_data},
                return_document=True,
            )

            if result:
                # Create system message for info update
                if name and name != old_name:
                    await MessagingService._create_system_message(
                        conversation_id,
                        SystemEventType.GROUP_INFO_UPDATED,
                        user_id,
                        [],
                        old_value=old_name,
                        new_value=name
                    )

                conv = MessagingService._conversation_doc_to_model(result)
                return await MessagingService._populate_conversation_profiles(conv, user_id)
        except Exception:
            pass
        return None

    @staticmethod
    async def add_group_members(
        conversation_id: str,
        actor_id: str,
        user_ids: List[str]
    ) -> Optional[ConversationModel]:
        """Add members to a group."""
        conv = await MessagingService.get_conversation(conversation_id, actor_id)
        if not conv or conv.type != ConversationType.GROUP:
            return None

        # Check permissions
        if conv.group_info:
            if not conv.group_info.settings.allow_member_invites:
                if actor_id not in conv.group_info.admins:
                    return None

        now = datetime.now(timezone.utc)

        # Prepare new members settings
        new_settings = {}
        for user_id in user_ids:
            if user_id not in conv.participants:
                new_settings[f"settings.{user_id}"] = {
                    "is_muted": False,
                    "is_archived": False,
                    "is_pinned": False
                }

        new_participants = [uid for uid in user_ids if uid not in conv.participants]
        if not new_participants:
            return conv

        try:
            update = {
                "$addToSet": {"participants": {"$each": new_participants}},
                "$set": {**new_settings, "updated_at": now}
            }

            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id)},
                update,
                return_document=True,
            )

            if result:
                # Create system message
                await MessagingService._create_system_message(
                    conversation_id,
                    SystemEventType.MEMBER_ADDED,
                    actor_id,
                    new_participants
                )

                conv = MessagingService._conversation_doc_to_model(result)
                return await MessagingService._populate_conversation_profiles(conv, actor_id)
        except Exception:
            pass
        return None

    @staticmethod
    async def remove_group_member(
        conversation_id: str,
        actor_id: str,
        user_id: str
    ) -> Optional[ConversationModel]:
        """Remove a member from a group (admin only)."""
        conv = await MessagingService.get_conversation(conversation_id, actor_id)
        if not conv or conv.type != ConversationType.GROUP:
            return None

        # Only admins can remove members
        if conv.group_info and actor_id not in conv.group_info.admins:
            return None

        # Cannot remove yourself this way (use leave_group)
        if actor_id == user_id:
            return None

        # Cannot remove the creator
        if conv.group_info and user_id == conv.group_info.created_by:
            return None

        now = datetime.now(timezone.utc)

        try:
            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id)},
                {
                    "$pull": {
                        "participants": user_id,
                        "group_info.admins": user_id
                    },
                    "$unset": {f"settings.{user_id}": ""},
                    "$set": {"updated_at": now}
                },
                return_document=True,
            )

            if result:
                # Create system message
                await MessagingService._create_system_message(
                    conversation_id,
                    SystemEventType.MEMBER_REMOVED,
                    actor_id,
                    [user_id]
                )

                conv = MessagingService._conversation_doc_to_model(result)
                return await MessagingService._populate_conversation_profiles(conv, actor_id)
        except Exception:
            pass
        return None

    @staticmethod
    async def leave_group(
        conversation_id: str,
        user_id: str
    ) -> bool:
        """Leave a group conversation."""
        conv = await MessagingService.get_conversation(conversation_id, user_id)
        if not conv or conv.type != ConversationType.GROUP:
            return False

        now = datetime.now(timezone.utc)

        # Check if user is the only admin
        is_admin = conv.group_info and user_id in conv.group_info.admins
        other_admins = [a for a in (conv.group_info.admins if conv.group_info else []) if a != user_id]
        other_participants = [p for p in conv.participants if p != user_id]

        try:
            update: Dict[str, Any] = {
                "$pull": {
                    "participants": user_id,
                    "group_info.admins": user_id
                },
                "$unset": {f"settings.{user_id}": ""},
                "$set": {"updated_at": now}
            }

            # If leaving user is the only admin and there are other participants, promote one
            if is_admin and not other_admins and other_participants:
                # Promote the first other participant to admin
                new_admin = other_participants[0]
                update["$addToSet"] = {"group_info.admins": new_admin}

            await Collections.conversations().update_one(
                {"_id": ObjectId(conversation_id)},
                update
            )

            # Create system message
            await MessagingService._create_system_message(
                conversation_id,
                SystemEventType.MEMBER_LEFT,
                user_id,
                [user_id]
            )

            return True
        except Exception:
            return False

    @staticmethod
    async def add_group_admin(
        conversation_id: str,
        actor_id: str,
        user_id: str
    ) -> Optional[ConversationModel]:
        """Promote a group member to admin."""
        conv = await MessagingService.get_conversation(conversation_id, actor_id)
        if not conv or conv.type != ConversationType.GROUP:
            return None

        # Only existing admins can promote
        if conv.group_info and actor_id not in conv.group_info.admins:
            return None

        # User must be a participant
        if user_id not in conv.participants:
            return None

        # User already an admin
        if conv.group_info and user_id in conv.group_info.admins:
            return conv

        now = datetime.now(timezone.utc)

        try:
            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id)},
                {
                    "$addToSet": {"group_info.admins": user_id},
                    "$set": {"updated_at": now}
                },
                return_document=True,
            )

            if result:
                # Create system message
                await MessagingService._create_system_message(
                    conversation_id,
                    SystemEventType.ADMIN_ADDED,
                    actor_id,
                    [user_id]
                )

                conv = MessagingService._conversation_doc_to_model(result)
                return await MessagingService._populate_conversation_profiles(conv, actor_id)
        except Exception:
            pass
        return None

    @staticmethod
    async def remove_group_admin(
        conversation_id: str,
        actor_id: str,
        user_id: str
    ) -> Optional[ConversationModel]:
        """Demote a group admin."""
        conv = await MessagingService.get_conversation(conversation_id, actor_id)
        if not conv or conv.type != ConversationType.GROUP:
            return None

        # Only admins can demote
        if conv.group_info and actor_id not in conv.group_info.admins:
            return None

        # Cannot demote the creator
        if conv.group_info and user_id == conv.group_info.created_by:
            return None

        # User must be an admin
        if not conv.group_info or user_id not in conv.group_info.admins:
            return conv

        now = datetime.now(timezone.utc)

        try:
            result = await Collections.conversations().find_one_and_update(
                {"_id": ObjectId(conversation_id)},
                {
                    "$pull": {"group_info.admins": user_id},
                    "$set": {"updated_at": now}
                },
                return_document=True,
            )

            if result:
                # Create system message
                await MessagingService._create_system_message(
                    conversation_id,
                    SystemEventType.ADMIN_REMOVED,
                    actor_id,
                    [user_id]
                )

                conv = MessagingService._conversation_doc_to_model(result)
                return await MessagingService._populate_conversation_profiles(conv, actor_id)
        except Exception:
            pass
        return None

    @staticmethod
    async def _create_system_message(
        conversation_id: str,
        event_type: SystemEventType,
        actor_id: str,
        target_ids: List[str],
        old_value: Optional[str] = None,
        new_value: Optional[str] = None
    ) -> Optional[MessageModel]:
        """Create a system message for group events."""
        now = datetime.now(timezone.utc)

        # Generate human-readable content
        content = MessagingService._generate_system_message_content(
            event_type, actor_id, target_ids, old_value, new_value
        )

        doc = {
            "conversation_id": ObjectId(conversation_id),
            "sender_id": "system",
            "message_type": MessageType.SYSTEM.value,
            "content": content,
            "status": MessageStatus.SENT.value,
            "system_event": {
                "event_type": event_type.value,
                "actor_id": actor_id,
                "target_ids": target_ids,
                "old_value": old_value,
                "new_value": new_value,
            },
            "created_at": now,
        }

        try:
            result = await Collections.messages().insert_one(doc)
            doc["_id"] = result.inserted_id

            # Update conversation's last message
            await Collections.conversations().update_one(
                {"_id": ObjectId(conversation_id)},
                {
                    "$set": {
                        "last_message": {
                            "text": content,
                            "type": MessageType.SYSTEM.value,
                            "sender_id": "system",
                            "at": now,
                        },
                        "updated_at": now,
                    }
                }
            )

            return MessagingService._message_doc_to_model(doc)
        except Exception:
            return None

    @staticmethod
    def _generate_system_message_content(
        event_type: SystemEventType,
        actor_id: str,
        target_ids: List[str],
        old_value: Optional[str],
        new_value: Optional[str]
    ) -> str:
        """Generate human-readable content for system messages."""
        # These will be formatted on the frontend with actual names
        if event_type == SystemEventType.GROUP_CREATED:
            return f"{{user:{actor_id}}} created this group"
        elif event_type == SystemEventType.MEMBER_ADDED:
            targets = ", ".join([f"{{user:{uid}}}" for uid in target_ids])
            return f"{{user:{actor_id}}} added {targets}"
        elif event_type == SystemEventType.MEMBER_REMOVED:
            targets = ", ".join([f"{{user:{uid}}}" for uid in target_ids])
            return f"{{user:{actor_id}}} removed {targets}"
        elif event_type == SystemEventType.MEMBER_LEFT:
            return f"{{user:{actor_id}}} left the group"
        elif event_type == SystemEventType.ADMIN_ADDED:
            targets = ", ".join([f"{{user:{uid}}}" for uid in target_ids])
            return f"{{user:{actor_id}}} made {targets} an admin"
        elif event_type == SystemEventType.ADMIN_REMOVED:
            targets = ", ".join([f"{{user:{uid}}}" for uid in target_ids])
            return f"{{user:{actor_id}}} removed {targets} as admin"
        elif event_type == SystemEventType.GROUP_INFO_UPDATED:
            if old_value and new_value:
                return f"{{user:{actor_id}}} changed the group name to \"{new_value}\""
            return f"{{user:{actor_id}}} updated the group info"
        elif event_type == SystemEventType.GROUP_ICON_UPDATED:
            return f"{{user:{actor_id}}} changed the group icon"
        return "Group updated"

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

    @staticmethod
    async def delete_expired_messages() -> int:
        """Hard-delete messages whose disappears_at has passed and clean up S3 attachments.

        Returns the number of messages deleted.
        """
        now = datetime.now(timezone.utc)
        cursor = Collections.messages().find({
            "disappears_at": {"$lte": now, "$ne": None}
        })
        deleted = 0
        async for doc in cursor:
            # Delete S3 attachment if present
            if doc.get("file") and doc["file"].get("url"):
                try:
                    StorageService.delete_file_by_url(doc["file"]["url"])
                except Exception:
                    pass
            await Collections.messages().delete_one({"_id": doc["_id"]})
            deleted += 1
        return deleted
