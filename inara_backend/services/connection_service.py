"""
Connection service for network management, blocking, and reporting.
"""

from datetime import datetime, timezone
from typing import Optional, List
from bson import ObjectId

from db.collections import Collections
from api.models.connection import (
    ConnectionModel,
    ConnectionStatus,
    NetworkContactModel,
    PendingRequestModel,
    SuggestedContactModel,
    BlockedUserModel,
    UserReportModel,
    UserReportCreate,
)
from services.profile_service import ProfileService


class ConnectionService:
    """Service for connection operations."""

    # ==================== Connections ====================

    @staticmethod
    def _connection_doc_to_model(doc: dict) -> ConnectionModel:
        """Convert MongoDB document to ConnectionModel."""
        return ConnectionModel(
            id=str(doc["_id"]),
            requester_id=doc["requester_id"],
            recipient_id=doc["recipient_id"],
            status=ConnectionStatus(doc.get("status", "pending")),
            request_message=doc.get("request_message"),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
            accepted_at=doc.get("accepted_at"),
            deleted_at=doc.get("deleted_at"),
            deleted_by=doc.get("deleted_by"),
        )

    @staticmethod
    async def get_network(user_id: str) -> List[NetworkContactModel]:
        """Get all accepted connections for a user."""
        cursor = Collections.connections().find({
            "$or": [
                {"requester_id": user_id, "status": ConnectionStatus.ACCEPTED.value},
                {"recipient_id": user_id, "status": ConnectionStatus.ACCEPTED.value},
            ],
            "deleted_at": None,
        }).sort("accepted_at", -1)

        contacts = []
        async for doc in cursor:
            # Determine the other user
            other_user_id = (
                doc["recipient_id"] if doc["requester_id"] == user_id
                else doc["requester_id"]
            )

            # Get profile
            profile = await ProfileService.get_by_user_id(other_user_id)
            if profile:
                contacts.append(NetworkContactModel(
                    connection_id=str(doc["_id"]),
                    user_id=other_user_id,
                    display_name=profile.display_name,
                    first_name=profile.first_name,
                    last_name=profile.last_name,
                    avatar_url=profile.avatar_url,
                    specialization=profile.specialization,
                    clinic_name=profile.clinic_name,
                    connected_at=doc.get("accepted_at", doc["created_at"]),
                ))

        return contacts

    @staticmethod
    async def search_network(user_id: str, query: str) -> List[NetworkContactModel]:
        """Search within user's network."""
        network = await ConnectionService.get_network(user_id)

        query_lower = query.lower()
        return [
            contact for contact in network
            if (contact.display_name and query_lower in contact.display_name.lower())
            or (contact.first_name and query_lower in contact.first_name.lower())
            or (contact.last_name and query_lower in contact.last_name.lower())
            or (contact.specialization and query_lower in contact.specialization.lower())
        ]

    @staticmethod
    async def get_pending_requests(user_id: str) -> List[PendingRequestModel]:
        """Get incoming pending connection requests."""
        cursor = Collections.connections().find({
            "recipient_id": user_id,
            "status": ConnectionStatus.PENDING.value,
        }).sort("created_at", -1)

        requests = []
        async for doc in cursor:
            profile = await ProfileService.get_by_user_id(doc["requester_id"])
            if profile:
                requests.append(PendingRequestModel(
                    connection_id=str(doc["_id"]),
                    requester_id=doc["requester_id"],
                    display_name=profile.display_name,
                    first_name=profile.first_name,
                    last_name=profile.last_name,
                    avatar_url=profile.avatar_url,
                    specialization=profile.specialization,
                    clinic_name=profile.clinic_name,
                    request_message=doc.get("request_message"),
                    created_at=doc["created_at"],
                ))

        return requests

    @staticmethod
    async def get_sent_requests(user_id: str) -> List[str]:
        """Get user IDs of sent pending requests."""
        cursor = Collections.connections().find({
            "requester_id": user_id,
            "status": ConnectionStatus.PENDING.value,
        }, {"recipient_id": 1})

        user_ids = []
        async for doc in cursor:
            user_ids.append(doc["recipient_id"])

        return user_ids

    @staticmethod
    async def get_suggestions(user_id: str, limit: int = 20) -> List[SuggestedContactModel]:
        """Get suggested connections (users not yet connected)."""
        # Get existing connection user IDs
        existing_cursor = Collections.connections().find({
            "$or": [
                {"requester_id": user_id},
                {"recipient_id": user_id},
            ]
        })

        connected_ids = {user_id}  # Include self
        request_status_map = {}

        async for doc in existing_cursor:
            other_id = (
                doc["recipient_id"] if doc["requester_id"] == user_id
                else doc["requester_id"]
            )
            connected_ids.add(other_id)

            # Track pending requests
            if doc["status"] == ConnectionStatus.PENDING.value:
                request_status_map[other_id] = {
                    "status": ConnectionStatus.PENDING,
                    "sent_by_me": doc["requester_id"] == user_id,
                }

        # Get blocked users
        blocked_cursor = Collections.blocked_users().find({
            "$or": [
                {"blocker_id": user_id},
                {"blocked_id": user_id},
            ]
        })

        async for doc in blocked_cursor:
            connected_ids.add(doc["blocker_id"])
            connected_ids.add(doc["blocked_id"])

        # Find profiles not in connected set
        cursor = Collections.profiles().find({
            "user_id": {"$nin": list(connected_ids)},
            "profile_completed": True,
        }).limit(limit)

        suggestions = []
        async for doc in cursor:
            profile_user_id = doc["user_id"]
            request_info = request_status_map.get(profile_user_id)

            suggestions.append(SuggestedContactModel(
                user_id=profile_user_id,
                display_name=doc.get("display_name"),
                first_name=doc.get("first_name"),
                last_name=doc.get("last_name"),
                avatar_url=doc.get("avatar_url"),
                specialization=doc.get("specialization"),
                clinic_name=doc.get("clinic_name"),
                mutual_connections=0,  # TODO: Calculate mutual connections
                request_status=request_info["status"] if request_info else None,
                request_sent_by_me=request_info["sent_by_me"] if request_info else False,
            ))

        return suggestions

    @staticmethod
    async def send_request(
        requester_id: str,
        recipient_id: str,
        message: Optional[str] = None
    ) -> Optional[ConnectionModel]:
        """Send a connection request."""
        # Check if already connected or pending
        existing = await Collections.connections().find_one({
            "$or": [
                {"requester_id": requester_id, "recipient_id": recipient_id},
                {"requester_id": recipient_id, "recipient_id": requester_id},
            ]
        })

        if existing:
            # Already exists
            return ConnectionService._connection_doc_to_model(existing)

        # Check if blocked
        blocked = await Collections.blocked_users().find_one({
            "$or": [
                {"blocker_id": requester_id, "blocked_id": recipient_id},
                {"blocker_id": recipient_id, "blocked_id": requester_id},
            ]
        })

        if blocked:
            return None

        now = datetime.now(timezone.utc)
        doc = {
            "requester_id": requester_id,
            "recipient_id": recipient_id,
            "status": ConnectionStatus.PENDING.value,
            "request_message": message,
            "created_at": now,
        }

        result = await Collections.connections().insert_one(doc)
        doc["_id"] = result.inserted_id

        return ConnectionService._connection_doc_to_model(doc)

    @staticmethod
    async def accept_request(connection_id: str, user_id: str) -> Optional[ConnectionModel]:
        """Accept a connection request."""
        try:
            result = await Collections.connections().find_one_and_update(
                {
                    "_id": ObjectId(connection_id),
                    "recipient_id": user_id,
                    "status": ConnectionStatus.PENDING.value,
                },
                {
                    "$set": {
                        "status": ConnectionStatus.ACCEPTED.value,
                        "accepted_at": datetime.now(timezone.utc),
                    }
                },
                return_document=True,
            )
            if result:
                return ConnectionService._connection_doc_to_model(result)
        except Exception:
            pass
        return None

    @staticmethod
    async def reject_request(connection_id: str, user_id: str) -> bool:
        """Reject a connection request."""
        try:
            result = await Collections.connections().update_one(
                {
                    "_id": ObjectId(connection_id),
                    "recipient_id": user_id,
                    "status": ConnectionStatus.PENDING.value,
                },
                {
                    "$set": {
                        "status": ConnectionStatus.REJECTED.value,
                    }
                }
            )
            return result.modified_count > 0
        except Exception:
            return False

    @staticmethod
    async def remove_connection(connection_id: str, user_id: str) -> bool:
        """Remove an existing connection (soft delete)."""
        try:
            result = await Collections.connections().update_one(
                {
                    "_id": ObjectId(connection_id),
                    "$or": [
                        {"requester_id": user_id},
                        {"recipient_id": user_id},
                    ],
                    "status": ConnectionStatus.ACCEPTED.value,
                },
                {
                    "$set": {
                        "deleted_at": datetime.now(timezone.utc),
                        "deleted_by": user_id,
                    }
                }
            )
            return result.modified_count > 0
        except Exception:
            return False

    @staticmethod
    async def get_connection_status(user_id: str, other_user_id: str) -> Optional[ConnectionModel]:
        """Get connection status between two users."""
        doc = await Collections.connections().find_one({
            "$or": [
                {"requester_id": user_id, "recipient_id": other_user_id},
                {"requester_id": other_user_id, "recipient_id": user_id},
            ],
            "deleted_at": None,
        })

        if doc:
            return ConnectionService._connection_doc_to_model(doc)
        return None

    # ==================== Blocking ====================

    @staticmethod
    async def block_user(
        blocker_id: str,
        blocked_id: str,
        reason: Optional[str] = None
    ) -> Optional[BlockedUserModel]:
        """Block a user."""
        # Check if already blocked
        existing = await Collections.blocked_users().find_one({
            "blocker_id": blocker_id,
            "blocked_id": blocked_id,
        })

        if existing:
            return BlockedUserModel(
                id=str(existing["_id"]),
                blocker_id=existing["blocker_id"],
                blocked_id=existing["blocked_id"],
                reason=existing.get("reason"),
                blocked_at=existing["blocked_at"],
            )

        now = datetime.now(timezone.utc)
        doc = {
            "blocker_id": blocker_id,
            "blocked_id": blocked_id,
            "reason": reason,
            "blocked_at": now,
        }

        result = await Collections.blocked_users().insert_one(doc)

        # Also remove any existing connection
        await Collections.connections().update_many(
            {
                "$or": [
                    {"requester_id": blocker_id, "recipient_id": blocked_id},
                    {"requester_id": blocked_id, "recipient_id": blocker_id},
                ]
            },
            {
                "$set": {
                    "status": ConnectionStatus.BLOCKED.value,
                    "deleted_at": now,
                    "deleted_by": blocker_id,
                }
            }
        )

        return BlockedUserModel(
            id=str(result.inserted_id),
            blocker_id=blocker_id,
            blocked_id=blocked_id,
            reason=reason,
            blocked_at=now,
        )

    @staticmethod
    async def unblock_user(blocker_id: str, blocked_id: str) -> bool:
        """Unblock a user."""
        result = await Collections.blocked_users().delete_one({
            "blocker_id": blocker_id,
            "blocked_id": blocked_id,
        })
        return result.deleted_count > 0

    @staticmethod
    async def get_blocked_users(user_id: str) -> List[BlockedUserModel]:
        """Get list of blocked users."""
        cursor = Collections.blocked_users().find({
            "blocker_id": user_id
        }).sort("blocked_at", -1)

        blocked = []
        async for doc in cursor:
            profile = await ProfileService.get_by_user_id(doc["blocked_id"])
            blocked_user = BlockedUserModel(
                id=str(doc["_id"]),
                blocker_id=doc["blocker_id"],
                blocked_id=doc["blocked_id"],
                reason=doc.get("reason"),
                blocked_at=doc["blocked_at"],
            )

            if profile:
                blocked_user.blocked_user = {
                    "user_id": profile.user_id,
                    "display_name": profile.display_name,
                    "avatar_url": profile.avatar_url,
                }

            blocked.append(blocked_user)

        return blocked

    @staticmethod
    async def is_blocked(user_id: str, other_user_id: str) -> bool:
        """Check if either user has blocked the other."""
        blocked = await Collections.blocked_users().find_one({
            "$or": [
                {"blocker_id": user_id, "blocked_id": other_user_id},
                {"blocker_id": other_user_id, "blocked_id": user_id},
            ]
        })
        return blocked is not None

    # ==================== Reporting ====================

    @staticmethod
    async def report_user(
        reporter_id: str,
        data: UserReportCreate
    ) -> UserReportModel:
        """Report a user for inappropriate behavior."""
        now = datetime.now(timezone.utc)
        doc = {
            "reporter_id": reporter_id,
            "reported_user_id": data.reported_user_id,
            "reason": data.reason,
            "description": data.description,
            "message_id": data.message_id,
            "status": "pending",
            "created_at": now,
        }

        result = await Collections.user_reports().insert_one(doc)

        return UserReportModel(
            id=str(result.inserted_id),
            reporter_id=reporter_id,
            reported_user_id=data.reported_user_id,
            reason=data.reason,
            description=data.description,
            message_id=data.message_id,
            status="pending",
            created_at=now,
        )
