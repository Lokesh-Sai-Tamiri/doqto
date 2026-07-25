"""Cross-stack enum contract. Wire values MUST match docs/enums.md and lib/core/enums/*.dart.

Python 3.11+ `StrEnum`: member value IS the wire string. A CI parity check
(`scripts/check_enum_parity.py`) verifies this file against docs/enums.md
and the Dart enums on every build.
"""

from enum import StrEnum


class UserRole(StrEnum):
    DOCTOR = "doctor"
    SUPER_ADMIN = "super_admin"


class OrgStatus(StrEnum):
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"


class OrgRole(StrEnum):
    ADMIN = "admin"
    DOCTOR = "doctor"


class PracticeType(StrEnum):
    INDEPENDENT = "independent"
    SPECIALTY_GROUP = "specialty_group"
    COMMUNITY_HOSPITAL = "community_hospital"


class ConversationType(StrEnum):
    DIRECT = "direct"
    GROUP = "group"


class ConversationAccess(StrEnum):
    OPEN = "open"
    PENDING_REQUEST = "pending_request"
    DECLINED = "declined"


class ExternalDmPolicy(StrEnum):
    """Backend-only org admin policy — not mirrored in Dart (no client wire use)."""

    DISABLED = "disabled"
    CONNECTIONS_ONLY = "connections_only"
    CONNECTIONS_AND_REQUESTS = "connections_and_requests"


class DirectoryVisibility(StrEnum):
    """Backend-only org admin policy — not mirrored in Dart (no client wire use)."""

    ORG_ONLY = "org_only"
    NETWORK = "network"
    PUBLIC = "public"


class MessageType(StrEnum):
    TEXT = "text"
    VOICE_NOTE = "voice_note"
    IMAGE = "image"
    FILE = "file"
    SYSTEM = "system"


class TranscriptStatus(StrEnum):
    NONE = "none"
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"


class PresenceStatus(StrEnum):
    ONLINE = "online"
    AWAY = "away"
    OFFLINE = "offline"


class WsEventServer(StrEnum):
    NEW_MESSAGE = "new_message"
    TRANSCRIPT_READY = "transcript_ready"
    MESSAGE_DELIVERED = "message_delivered"
    MESSAGE_READ = "message_read"
    PRESENCE_UPDATE = "presence_update"
    MEMBER_ADDED = "member_added"
    MEMBER_REMOVED = "member_removed"
    SYSTEM_MESSAGE = "system_message"
    TYPING_START = "typing_start"
    TYPING_STOP = "typing_stop"
    HEARTBEAT_ACK = "heartbeat_ack"


class WsEventClient(StrEnum):
    HEARTBEAT = "heartbeat"
    TYPING_START = "typing_start"
    TYPING_STOP = "typing_stop"


class DevicePlatform(StrEnum):
    IOS = "ios"
    ANDROID = "android"


class JwtTokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


class AuditAction(StrEnum):
    LOGIN = "login"
    LOGOUT = "logout"
    REGISTER = "register"
    OTP_REQUESTED = "otp_requested"
    OTP_VERIFIED = "otp_verified"
    ORG_CREATED = "org_created"
    ORG_JOINED = "org_joined"
    ORG_VERIFIED = "org_verified"
    ORG_POLICY_CHANGED = "org_policy_changed"
    MEMBER_REMOVED = "member_removed"
    CONVERSATION_CREATED = "conversation_created"
    CONVERSATION_ACCESSED = "conversation_accessed"
    GROUP_MEMBER_ADDED = "group_member_added"
    GROUP_MEMBER_LEFT = "group_member_left"
    GROUP_MEMBER_REMOVED = "group_member_removed"
    MESSAGE_SENT = "message_sent"
    MESSAGE_READ = "message_read"
    FILE_UPLOADED = "file_uploaded"
    FILE_ACCESSED = "file_accessed"


class TranscribeSpecialty(StrEnum):
    PRIMARYCARE = "PRIMARYCARE"
    CARDIOLOGY = "CARDIOLOGY"
    RADIOLOGY = "RADIOLOGY"
    NEUROLOGY = "NEUROLOGY"
    UROLOGY = "UROLOGY"
