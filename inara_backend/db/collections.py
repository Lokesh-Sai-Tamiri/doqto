"""
MongoDB collection references and index management.
"""

from motor.motor_asyncio import AsyncIOMotorCollection
from pymongo import IndexModel, ASCENDING, DESCENDING

from db.mongodb import get_db


class Collections:
    """Collection name constants and access methods."""

    # Collection names
    PROFILES = "profiles"
    CONVERSATIONS = "conversations"
    MESSAGES = "messages"
    CONNECTIONS = "connections"
    MESSAGING_PREFERENCES = "messaging_preferences"
    BLOCKED_USERS = "blocked_users"
    USER_REPORTS = "user_reports"
    ORGANIZATIONS = "organizations"
    ORGANIZATION_MEMBERSHIPS = "organization_memberships"
    ORGANIZATION_DEPARTMENTS = "organization_departments"
    ORGANIZATION_INVITES = "organization_invites"
    ORG_SUBSCRIPTIONS = "org_subscriptions"
    STRIPE_EVENTS = "stripe_events"

    @classmethod
    def profiles(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.PROFILES]

    @classmethod
    def conversations(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.CONVERSATIONS]

    @classmethod
    def messages(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.MESSAGES]

    @classmethod
    def connections(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.CONNECTIONS]

    @classmethod
    def messaging_preferences(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.MESSAGING_PREFERENCES]

    @classmethod
    def blocked_users(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.BLOCKED_USERS]

    @classmethod
    def user_reports(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.USER_REPORTS]

    @classmethod
    def organizations(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.ORGANIZATIONS]

    @classmethod
    def organization_memberships(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.ORGANIZATION_MEMBERSHIPS]

    @classmethod
    def organization_departments(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.ORGANIZATION_DEPARTMENTS]

    @classmethod
    def organization_invites(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.ORGANIZATION_INVITES]

    @classmethod
    def org_subscriptions(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.ORG_SUBSCRIPTIONS]

    @classmethod
    def stripe_events(cls) -> AsyncIOMotorCollection:
        return get_db()[cls.STRIPE_EVENTS]


async def create_indexes() -> None:
    """Create all necessary indexes for optimal query performance."""

    db = get_db()

    # Profiles indexes
    await db[Collections.PROFILES].create_indexes([
        IndexModel([("user_id", ASCENDING)], unique=True),
        IndexModel([("phone", ASCENDING)]),
        IndexModel([("email", ASCENDING)]),
    ])

    # Conversations indexes
    await db[Collections.CONVERSATIONS].create_indexes([
        IndexModel([("participants", ASCENDING)]),
        IndexModel([("updated_at", DESCENDING)]),
    ])

    # Messages indexes
    await db[Collections.MESSAGES].create_indexes([
        IndexModel([("conversation_id", ASCENDING), ("created_at", DESCENDING)]),
        IndexModel([("sender_id", ASCENDING)]),
        IndexModel([("saved_by", ASCENDING)]),
        IndexModel(
            [("disappears_at", ASCENDING)],
            expireAfterSeconds=0,
            partialFilterExpression={"disappears_at": {"$type": "date"}},
        ),
    ])

    # Connections indexes
    await db[Collections.CONNECTIONS].create_indexes([
        IndexModel(
            [("requester_id", ASCENDING), ("recipient_id", ASCENDING)],
            unique=True
        ),
        IndexModel([("recipient_id", ASCENDING), ("status", ASCENDING)]),
        IndexModel([("requester_id", ASCENDING), ("status", ASCENDING)]),
    ])

    # Messaging preferences indexes
    await db[Collections.MESSAGING_PREFERENCES].create_indexes([
        IndexModel([("user_id", ASCENDING)], unique=True),
    ])

    # Blocked users indexes
    await db[Collections.BLOCKED_USERS].create_indexes([
        IndexModel(
            [("blocker_id", ASCENDING), ("blocked_id", ASCENDING)],
            unique=True
        ),
        IndexModel([("blocked_id", ASCENDING)]),
    ])

    # Organizations indexes
    await db[Collections.ORGANIZATIONS].create_indexes([
        IndexModel([("name", ASCENDING)]),
        IndexModel([("is_public", ASCENDING)]),
    ])

    # Organization memberships indexes
    await db[Collections.ORGANIZATION_MEMBERSHIPS].create_indexes([
        IndexModel([("user_id", ASCENDING)]),
        IndexModel([("organization_id", ASCENDING)]),
        IndexModel(
            [("organization_id", ASCENDING), ("user_id", ASCENDING)],
            unique=True
        ),
    ])

    # Organization departments indexes
    await db[Collections.ORGANIZATION_DEPARTMENTS].create_indexes([
        IndexModel([("organization_id", ASCENDING)]),
    ])

    # Organization invites indexes
    await db[Collections.ORGANIZATION_INVITES].create_indexes([
        IndexModel([("invite_code", ASCENDING)], unique=True),
        IndexModel([("organization_id", ASCENDING)]),
        IndexModel([("expires_at", ASCENDING)]),
    ])

    # Org subscriptions indexes
    await db[Collections.ORG_SUBSCRIPTIONS].create_indexes([
        IndexModel([("org_id", ASCENDING)], unique=True),
        IndexModel([("stripe_subscription_id", ASCENDING)]),
    ])

    # Stripe events idempotency indexes
    await db[Collections.STRIPE_EVENTS].create_indexes([
        IndexModel([("stripe_event_id", ASCENDING)], unique=True),
    ])

    print("All indexes created successfully")
