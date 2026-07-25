"""API route paths — mirrored in lib/core/constants/api_routes.dart on Flutter."""


class ApiPrefix:
    V1 = "/api/v1"
    AUTH = "/api/v1/auth"
    ORGS = "/api/v1/orgs"
    USERS = "/api/v1/users"
    CONVERSATIONS = "/api/v1/conversations"
    MESSAGES = "/api/v1/messages"
    ADMIN = "/api/v1/admin"
    NETWORK = "/api/v1/network"
    NOTIFICATIONS = "/api/v1/notifications"
    PEOPLE = "/api/v1/people"


class ApiRoutes:
    # Auth
    AUTH_REQUEST_OTP = "/request-otp"
    AUTH_VERIFY_OTP = "/verify-otp"
    AUTH_REFRESH = "/refresh"
    AUTH_LOGOUT = "/logout"
    AUTH_REGISTER = "/register"

    # Orgs
    ORGS_CREATE = ""
    ORGS_JOIN = "/join"
    ORGS_MINE = "/mine"
    ORGS_DETAIL = "/{org_id}"
    ORGS_MEMBERS = "/{org_id}/members"
    ORGS_MEMBER_DETAIL = "/{org_id}/members/{user_id}"
    ORGS_INVITE_CODE = "/{org_id}/invite-code"
    ORGS_NETWORKING_SETTINGS = "/{org_id}/settings/networking"

    # Users
    USERS_PUSH_TOKENS = "/me/push-tokens"
    USERS_PRIVACY = "/me/privacy"
    USERS_PROFILE = "/{user_id}/profile"  # public profile (M2) — no PHI

    # People search (M2) — cross-org directory surface
    PEOPLE_SEARCH = "/search"

    # Network (M1)
    NETWORK_INVITATIONS = "/invitations"
    NETWORK_INVITATION_ACCEPT = "/invitations/{invitation_id}/accept"
    NETWORK_INVITATION_IGNORE = "/invitations/{invitation_id}/ignore"
    NETWORK_INVITATION_DETAIL = "/invitations/{invitation_id}"
    NETWORK_CONNECTIONS = "/connections"
    NETWORK_CONNECTION_DETAIL = "/connections/{user_id}"
    NETWORK_CONNECTIONS_MUTUAL = "/connections/mutual/{user_id}"
    NETWORK_BLOCKS = "/blocks"
    NETWORK_BLOCK_DETAIL = "/blocks/{user_id}"
    NETWORK_MUTES = "/mutes"
    NETWORK_MUTE_DETAIL = "/mutes/{user_id}"
    NETWORK_REPORTS = "/reports"

    # Notifications (M1)
    NOTIFICATIONS_LIST = ""
    NOTIFICATIONS_READ = "/read"
    NOTIFICATIONS_UNREAD_COUNT = "/unread-count"

    # Conversations
    CONVERSATIONS_LIST = ""
    CONVERSATIONS_CREATE = ""
    CONVERSATIONS_MESSAGES = "/{conversation_id}/messages"
    CONVERSATIONS_READ = "/{conversation_id}/read"
    CONVERSATIONS_DELIVERED = "/{conversation_id}/delivered"
    CONVERSATIONS_UPLOAD = "/{conversation_id}/messages/upload"
    CONVERSATIONS_VOICE_NOTE = "/{conversation_id}/voice-notes"
    CONVERSATIONS_MEMBERS = "/{conversation_id}/members"
    CONVERSATIONS_MEMBER_DETAIL = "/{conversation_id}/members/{user_id}"
    CONVERSATIONS_SETTINGS = "/{conversation_id}/settings"

    # Messages
    MESSAGES_READ = "/{message_id}/read"
    MESSAGES_FILE_URL = "/{message_id}/file-url"

    # Admin
    ADMIN_ORGS = "/orgs"
    ADMIN_VERIFY_ORG = "/orgs/{org_id}/verify"
    ADMIN_REJECT_ORG = "/orgs/{org_id}/reject"

    # WebSocket
    WS = "/ws"  # user-scoped socket (A1)
    WS_ORG = "/ws/{org_id}"  # legacy alias — path org ignored, one release only
