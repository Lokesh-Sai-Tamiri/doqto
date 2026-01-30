"""
Organization service for hospitals, clinics, departments, and memberships.
"""

from datetime import datetime, timezone, timedelta
from typing import Optional, List
from bson import ObjectId
import secrets
import string

from db.collections import Collections
from api.models.organization import (
    OrganizationModel,
    OrganizationCreate,
    OrganizationType,
    MemberRole,
    MemberStatus,
    MyOrganizationModel,
    DepartmentModel,
    DepartmentCreate,
    ColleagueModel,
    OrganizationInviteModel,
    OrganizationInviteCreate,
)
from services.profile_service import ProfileService
from services.connection_service import ConnectionService


class OrganizationService:
    """Service for organization operations."""

    # ==================== Organizations ====================

    @staticmethod
    def _org_doc_to_model(doc: dict) -> OrganizationModel:
        """Convert MongoDB document to OrganizationModel."""
        return OrganizationModel(
            id=str(doc["_id"]),
            name=doc["name"],
            type=OrganizationType(doc.get("type", "other")),
            description=doc.get("description"),
            contact=doc.get("contact"),
            address=doc.get("address"),
            logo_url=doc.get("logo_url"),
            is_public=doc.get("is_public", True),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
            updated_at=doc.get("updated_at"),
        )

    @staticmethod
    async def get_my_organizations(user_id: str) -> List[MyOrganizationModel]:
        """Get all organizations the user belongs to."""
        cursor = Collections.organization_memberships().find({
            "user_id": user_id,
            "status": {"$in": [MemberStatus.ACTIVE.value, MemberStatus.PENDING.value]},
        })

        orgs = []
        async for membership in cursor:
            # Get organization details
            org_doc = await Collections.organizations().find_one({
                "_id": membership["organization_id"]
            })

            if not org_doc:
                continue

            # Get department name if assigned
            department_name = None
            if membership.get("department_id"):
                dept = await Collections.organization_departments().find_one({
                    "_id": membership["department_id"]
                })
                if dept:
                    department_name = dept["name"]

            # Extract city/state from address if available
            address = org_doc.get("address") or {}
            city = address.get("city") if isinstance(address, dict) else None
            state = address.get("state") if isinstance(address, dict) else None

            # Count members in this org
            member_count = await Collections.organization_memberships().count_documents({
                "organization_id": org_doc["_id"],
                "status": MemberStatus.ACTIVE.value,
            })

            orgs.append(MyOrganizationModel(
                membership_id=str(membership["_id"]),
                organization_id=str(org_doc["_id"]),
                organization_name=org_doc["name"],
                organization_type=OrganizationType(org_doc.get("type", "other")),
                organization_logo_url=org_doc.get("logo_url"),
                city=city,
                state=state,
                role=MemberRole(membership.get("role", "member")),
                title=membership.get("title"),
                status=MemberStatus(membership.get("status", "active")),
                department_id=str(membership["department_id"]) if membership.get("department_id") else None,
                department_name=department_name,
                joined_at=membership.get("joined_at", datetime.now(timezone.utc)),
                member_count=member_count,
            ))

        return orgs

    @staticmethod
    async def get_organization(org_id: str, user_id: str) -> Optional[OrganizationModel]:
        """Get organization details if user is a member or org is public."""
        try:
            org_doc = await Collections.organizations().find_one({
                "_id": ObjectId(org_id)
            })

            if not org_doc:
                return None

            # Check if public or user is member
            if not org_doc.get("is_public", True):
                membership = await Collections.organization_memberships().find_one({
                    "organization_id": ObjectId(org_id),
                    "user_id": user_id,
                    "status": MemberStatus.ACTIVE.value,
                })
                if not membership:
                    return None

            return OrganizationService._org_doc_to_model(org_doc)
        except Exception:
            return None

    @staticmethod
    async def create_organization(user_id: str, data: OrganizationCreate) -> OrganizationModel:
        """Create a new organization with the user as owner."""
        now = datetime.now(timezone.utc)

        org_doc = {
            "name": data.name,
            "type": data.type.value,
            "description": data.description,
            "contact": data.contact.model_dump() if data.contact else None,
            "address": data.address.model_dump() if data.address else None,
            "is_public": data.is_public,
            "created_at": now,
        }

        result = await Collections.organizations().insert_one(org_doc)
        org_id = result.inserted_id

        # Add creator as owner
        membership_doc = {
            "organization_id": org_id,
            "user_id": user_id,
            "role": MemberRole.OWNER.value,
            "status": MemberStatus.ACTIVE.value,
            "joined_at": now,
        }

        await Collections.organization_memberships().insert_one(membership_doc)

        org_doc["_id"] = org_id
        return OrganizationService._org_doc_to_model(org_doc)

    @staticmethod
    async def leave_organization(org_id: str, user_id: str) -> bool:
        """Leave an organization."""
        try:
            # Check if user is owner
            membership = await Collections.organization_memberships().find_one({
                "organization_id": ObjectId(org_id),
                "user_id": user_id,
            })

            if not membership:
                return False

            if membership.get("role") == MemberRole.OWNER.value:
                # Owner can't leave, must transfer ownership first
                return False

            result = await Collections.organization_memberships().delete_one({
                "organization_id": ObjectId(org_id),
                "user_id": user_id,
            })
            return result.deleted_count > 0
        except Exception:
            return False

    # ==================== Departments ====================

    @staticmethod
    def _dept_doc_to_model(doc: dict) -> DepartmentModel:
        """Convert MongoDB document to DepartmentModel."""
        return DepartmentModel(
            id=str(doc["_id"]),
            organization_id=str(doc["organization_id"]),
            name=doc["name"],
            description=doc.get("description"),
            color=doc.get("color"),
            icon=doc.get("icon"),
            display_order=doc.get("display_order", 0),
            head_user_id=doc.get("head_user_id"),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
        )

    @staticmethod
    async def get_departments(org_id: str, user_id: str) -> List[DepartmentModel]:
        """Get all departments in an organization."""
        # Verify access
        org = await OrganizationService.get_organization(org_id, user_id)
        if not org:
            return []

        cursor = Collections.organization_departments().find({
            "organization_id": ObjectId(org_id)
        }).sort("display_order", 1)

        departments = []
        async for doc in cursor:
            departments.append(OrganizationService._dept_doc_to_model(doc))

        return departments

    @staticmethod
    async def create_department(
        org_id: str,
        user_id: str,
        data: DepartmentCreate
    ) -> Optional[DepartmentModel]:
        """Create a new department (admin/owner only)."""
        try:
            # Verify admin/owner access
            membership = await Collections.organization_memberships().find_one({
                "organization_id": ObjectId(org_id),
                "user_id": user_id,
                "role": {"$in": [MemberRole.OWNER.value, MemberRole.ADMIN.value]},
                "status": MemberStatus.ACTIVE.value,
            })

            if not membership:
                return None

            now = datetime.now(timezone.utc)
            doc = {
                "organization_id": ObjectId(org_id),
                "name": data.name,
                "description": data.description,
                "color": data.color,
                "icon": data.icon,
                "display_order": data.display_order,
                "head_user_id": data.head_user_id,
                "created_at": now,
            }

            result = await Collections.organization_departments().insert_one(doc)
            doc["_id"] = result.inserted_id

            return OrganizationService._dept_doc_to_model(doc)
        except Exception:
            return None

    # ==================== Colleagues ====================

    @staticmethod
    async def get_colleagues(org_id: str, user_id: str) -> List[ColleagueModel]:
        """Get all colleagues in an organization."""
        # Verify membership
        membership = await Collections.organization_memberships().find_one({
            "organization_id": ObjectId(org_id),
            "user_id": user_id,
            "status": MemberStatus.ACTIVE.value,
        })

        if not membership:
            return []

        cursor = Collections.organization_memberships().find({
            "organization_id": ObjectId(org_id),
            "status": MemberStatus.ACTIVE.value,
            "user_id": {"$ne": user_id},  # Exclude self
        })

        colleagues = []
        async for member in cursor:
            profile = await ProfileService.get_by_user_id(member["user_id"])
            if not profile:
                continue

            # Get department name
            department_name = None
            if member.get("department_id"):
                dept = await Collections.organization_departments().find_one({
                    "_id": member["department_id"]
                })
                if dept:
                    department_name = dept["name"]

            # Check connection status
            connection = await ConnectionService.get_connection_status(user_id, member["user_id"])
            is_connected = connection is not None and connection.status.value == "accepted"

            colleagues.append(ColleagueModel(
                user_id=member["user_id"],
                display_name=profile.display_name,
                first_name=profile.first_name,
                last_name=profile.last_name,
                avatar_url=profile.avatar_url,
                specialization=profile.specialization,
                role=MemberRole(member.get("role", "member")),
                title=member.get("title"),
                department_id=str(member["department_id"]) if member.get("department_id") else None,
                department_name=department_name,
                is_connected=is_connected,
            ))

        return colleagues

    @staticmethod
    async def search_colleagues(org_id: str, user_id: str, query: str) -> List[ColleagueModel]:
        """Search colleagues by name or specialization."""
        colleagues = await OrganizationService.get_colleagues(org_id, user_id)

        query_lower = query.lower()
        return [
            c for c in colleagues
            if (c.display_name and query_lower in c.display_name.lower())
            or (c.first_name and query_lower in c.first_name.lower())
            or (c.last_name and query_lower in c.last_name.lower())
            or (c.specialization and query_lower in c.specialization.lower())
        ]

    @staticmethod
    async def get_colleagues_by_department(
        org_id: str,
        department_id: str,
        user_id: str
    ) -> List[ColleagueModel]:
        """Get colleagues in a specific department."""
        colleagues = await OrganizationService.get_colleagues(org_id, user_id)
        return [c for c in colleagues if c.department_id == department_id]

    # ==================== Invites ====================

    @staticmethod
    def _generate_invite_code() -> str:
        """Generate a random invite code."""
        alphabet = string.ascii_uppercase + string.digits
        return ''.join(secrets.choice(alphabet) for _ in range(8))

    @staticmethod
    async def create_invite(
        org_id: str,
        user_id: str,
        data: OrganizationInviteCreate
    ) -> Optional[OrganizationInviteModel]:
        """Create an organization invite (admin/owner only)."""
        try:
            # Verify admin/owner access
            membership = await Collections.organization_memberships().find_one({
                "organization_id": ObjectId(org_id),
                "user_id": user_id,
                "role": {"$in": [MemberRole.OWNER.value, MemberRole.ADMIN.value]},
                "status": MemberStatus.ACTIVE.value,
            })

            if not membership:
                return None

            # Get org details
            org = await Collections.organizations().find_one({"_id": ObjectId(org_id)})
            if not org:
                return None

            # Get inviter profile
            inviter_profile = await ProfileService.get_by_user_id(user_id)

            now = datetime.now(timezone.utc)
            expires_at = now + timedelta(days=data.expires_in_days)

            # Get department name if specified
            department_name = None
            if data.department_id:
                dept = await Collections.organization_departments().find_one({
                    "_id": ObjectId(data.department_id)
                })
                if dept:
                    department_name = dept["name"]

            doc = {
                "organization_id": ObjectId(org_id),
                "department_id": ObjectId(data.department_id) if data.department_id else None,
                "inviter_id": user_id,
                "role": data.role.value,
                "invite_code": OrganizationService._generate_invite_code(),
                "expires_at": expires_at,
                "created_at": now,
            }

            result = await Collections.organization_invites().insert_one(doc)

            return OrganizationInviteModel(
                id=str(result.inserted_id),
                organization_id=org_id,
                organization_name=org["name"],
                department_id=data.department_id,
                department_name=department_name,
                inviter_id=user_id,
                inviter_name=inviter_profile.display_name if inviter_profile else None,
                role=data.role,
                invite_code=doc["invite_code"],
                expires_at=expires_at,
                created_at=now,
            )
        except Exception:
            return None

    @staticmethod
    async def get_my_pending_invites(user_id: str) -> List[OrganizationInviteModel]:
        """Get invites available to join (based on public invites for now)."""
        # This would typically involve a mapping table of invites sent to specific users
        # For simplicity, returning empty for now - users join via invite code
        return []

    @staticmethod
    async def join_by_code(user_id: str, invite_code: str) -> Optional[MyOrganizationModel]:
        """Join an organization using an invite code."""
        now = datetime.now(timezone.utc)

        # Find valid invite
        invite = await Collections.organization_invites().find_one({
            "invite_code": invite_code.upper(),
            "expires_at": {"$gt": now},
        })

        if not invite:
            return None

        org_id = invite["organization_id"]

        # Check if already a member
        existing = await Collections.organization_memberships().find_one({
            "organization_id": org_id,
            "user_id": user_id,
        })

        if existing:
            # Already a member
            orgs = await OrganizationService.get_my_organizations(user_id)
            return next((o for o in orgs if o.organization_id == str(org_id)), None)

        # Create membership
        membership_doc = {
            "organization_id": org_id,
            "user_id": user_id,
            "department_id": invite.get("department_id"),
            "role": invite.get("role", MemberRole.MEMBER.value),
            "status": MemberStatus.ACTIVE.value,
            "joined_at": now,
        }

        await Collections.organization_memberships().insert_one(membership_doc)

        # Return updated org list entry
        orgs = await OrganizationService.get_my_organizations(user_id)
        return next((o for o in orgs if o.organization_id == str(org_id)), None)

    @staticmethod
    async def update_member_department(
        membership_id: str,
        user_id: str,
        department_id: Optional[str]
    ) -> bool:
        """Update a member's department assignment."""
        try:
            # Get membership to verify it belongs to user
            membership = await Collections.organization_memberships().find_one({
                "_id": ObjectId(membership_id),
                "user_id": user_id,
            })

            if not membership:
                return False

            update_doc = {
                "department_id": ObjectId(department_id) if department_id else None
            }

            result = await Collections.organization_memberships().update_one(
                {"_id": ObjectId(membership_id)},
                {"$set": update_doc}
            )

            return result.modified_count > 0
        except Exception:
            return False
