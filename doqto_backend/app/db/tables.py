"""Single source of truth for table names. ORM models + Alembic migrations + raw SQL all reference these."""


class Tables:
    ORGANIZATIONS = "organizations"
    USERS = "users"
    ORG_MEMBERS = "org_members"
    CONVERSATIONS = "conversations"
    CONVERSATION_MEMBERS = "conversation_members"
    MESSAGES = "messages"
    MESSAGE_RECEIPTS = "message_receipts"
    AUDIT_LOGS = "audit_logs"
    DEVICE_TOKENS = "device_tokens"
