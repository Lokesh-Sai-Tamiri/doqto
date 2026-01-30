"""
Messaging models for conversations, messages, and preferences.
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum
from pydantic import BaseModel, Field


class MessageType(str, Enum):
    """Types of messages supported."""
    TEXT = "text"
    AUDIO = "audio"
    IMAGE = "image"
    DOCUMENT = "document"
    SYSTEM = "system"


class MessageStatus(str, Enum):
    """Message delivery status."""
    SENDING = "sending"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"


class WhoCanMessage(str, Enum):
    """Privacy settings for who can initiate messages."""
    EVERYONE = "everyone"
    CONNECTIONS = "connections"
    ORGANIZATION = "organization"
    NONE = "none"


class FileInfo(BaseModel):
    """File attachment information."""
    url: str
    name: Optional[str] = None
    size: Optional[int] = None
    mime_type: Optional[str] = None


class AudioInfo(BaseModel):
    """Audio message metadata."""
    duration_seconds: int = 0
    waveform: List[float] = Field(default_factory=list)


class LastMessage(BaseModel):
    """Last message summary for conversation list."""
    text: Optional[str] = None
    type: MessageType = MessageType.TEXT
    sender_id: str
    at: datetime


class ConversationSettingsEntry(BaseModel):
    """Per-user conversation settings."""
    is_muted: bool = False
    is_archived: bool = False
    is_pinned: bool = False
    disappearing_hours: Optional[int] = None


class ConversationSettings(BaseModel):
    """Update model for conversation settings."""
    is_muted: Optional[bool] = None
    is_archived: Optional[bool] = None
    is_pinned: Optional[bool] = None
    disappearing_hours: Optional[int] = None


class ConversationCreate(BaseModel):
    """Create or get a conversation with another user."""
    other_user_id: str = Field(..., description="The other participant's user ID")


class ConversationModel(BaseModel):
    """Full conversation model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    participants: List[str] = Field(..., min_length=2, max_length=2)
    settings: Dict[str, ConversationSettingsEntry] = Field(default_factory=dict)
    last_message: Optional[LastMessage] = None
    unread_count: int = 0
    created_at: datetime
    updated_at: datetime

    # Populated fields (for list view)
    other_user: Optional[Dict[str, Any]] = None
    is_blocked: bool = False
    blocked_by_other: bool = False

    class Config:
        from_attributes = True


class MessageCreate(BaseModel):
    """Create a new message."""
    message_type: MessageType = MessageType.TEXT
    content: Optional[str] = None
    file: Optional[FileInfo] = None
    audio: Optional[AudioInfo] = None
    reply_to_id: Optional[str] = None


class MessageModel(BaseModel):
    """Full message model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    conversation_id: str
    sender_id: str
    message_type: MessageType
    content: Optional[str] = None
    file: Optional[FileInfo] = None
    audio: Optional[AudioInfo] = None
    saved_by: Optional[str] = None
    saved_at: Optional[datetime] = None
    status: MessageStatus = MessageStatus.SENT
    delivered_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    disappears_at: Optional[datetime] = None
    reply_to_id: Optional[str] = None
    reply_to: Optional["MessageModel"] = None
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationSettings(BaseModel):
    """Notification preferences sub-document."""
    enabled: bool = True
    sound: bool = True
    vibration: bool = True


class MessagingPreferencesModel(BaseModel):
    """User messaging preferences."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    user_id: str
    who_can_message: WhoCanMessage = WhoCanMessage.EVERYONE
    read_receipts_enabled: bool = True
    show_typing_indicator: bool = True
    show_online_status: bool = True
    allow_audio_save: bool = False
    default_disappearing_hours: Optional[int] = None
    notifications: NotificationSettings = Field(default_factory=NotificationSettings)

    class Config:
        from_attributes = True


class MessagingPreferencesUpdate(BaseModel):
    """Update messaging preferences."""
    who_can_message: Optional[WhoCanMessage] = None
    read_receipts_enabled: Optional[bool] = None
    show_typing_indicator: Optional[bool] = None
    show_online_status: Optional[bool] = None
    allow_audio_save: Optional[bool] = None
    default_disappearing_hours: Optional[int] = None
    notifications: Optional[NotificationSettings] = None


class UnreadCountResponse(BaseModel):
    """Response for unread message count."""
    total_unread: int
    by_conversation: Dict[str, int] = Field(default_factory=dict)
