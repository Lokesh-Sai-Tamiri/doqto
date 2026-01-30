"""
Profile service for user profile CRUD operations.
"""

from datetime import datetime, timezone
from typing import Optional
from bson import ObjectId

from db.collections import Collections
from api.models.profile import ProfileModel, ProfileCreate, ProfileUpdate


class ProfileService:
    """Service for profile operations."""

    @staticmethod
    def _doc_to_model(doc: dict) -> ProfileModel:
        """Convert MongoDB document to ProfileModel."""
        return ProfileModel(
            id=str(doc["_id"]),
            user_id=doc["user_id"],
            first_name=doc.get("first_name"),
            last_name=doc.get("last_name"),
            display_name=doc.get("display_name"),
            email=doc.get("email"),
            phone=doc.get("phone"),
            doctor_id=doc.get("doctor_id"),
            specialization=doc.get("specialization"),
            clinic_name=doc.get("clinic_name"),
            years_of_experience=doc.get("years_of_experience"),
            address=doc.get("address"),
            avatar_url=doc.get("avatar_url"),
            bio=doc.get("bio"),
            profile_completed=doc.get("profile_completed", False),
            created_at=doc.get("created_at", datetime.now(timezone.utc)),
            updated_at=doc.get("updated_at", datetime.now(timezone.utc)),
        )

    @staticmethod
    async def get_by_user_id(user_id: str) -> Optional[ProfileModel]:
        """Get profile by Supabase user ID."""
        doc = await Collections.profiles().find_one({"user_id": user_id})
        if doc:
            return ProfileService._doc_to_model(doc)
        return None

    @staticmethod
    async def get_by_id(profile_id: str) -> Optional[ProfileModel]:
        """Get profile by MongoDB ObjectId."""
        try:
            doc = await Collections.profiles().find_one({"_id": ObjectId(profile_id)})
            if doc:
                return ProfileService._doc_to_model(doc)
        except Exception:
            pass
        return None

    @staticmethod
    async def create(user_id: str, data: ProfileCreate) -> ProfileModel:
        """Create a new profile."""
        now = datetime.now(timezone.utc)

        doc = {
            "user_id": user_id,
            "first_name": data.first_name,
            "last_name": data.last_name,
            "display_name": data.display_name,
            "email": data.email,
            "phone": data.phone,
            "doctor_id": data.doctor_id,
            "specialization": data.specialization,
            "clinic_name": data.clinic_name,
            "years_of_experience": data.years_of_experience,
            "address": data.address.model_dump() if data.address else None,
            "bio": data.bio,
            "avatar_url": None,
            "profile_completed": False,
            "created_at": now,
            "updated_at": now,
        }

        result = await Collections.profiles().insert_one(doc)
        doc["_id"] = result.inserted_id

        return ProfileService._doc_to_model(doc)

    @staticmethod
    async def update(user_id: str, data: ProfileUpdate) -> Optional[ProfileModel]:
        """Update an existing profile."""
        update_data = {}

        # Only include fields that are explicitly set
        for field, value in data.model_dump(exclude_unset=True).items():
            if field == "address" and value is not None:
                update_data["address"] = value
            else:
                update_data[field] = value

        if not update_data:
            # No changes, return current profile
            return await ProfileService.get_by_user_id(user_id)

        update_data["updated_at"] = datetime.now(timezone.utc)

        result = await Collections.profiles().find_one_and_update(
            {"user_id": user_id},
            {"$set": update_data},
            return_document=True,
        )

        if result:
            return ProfileService._doc_to_model(result)
        return None

    @staticmethod
    async def upsert(user_id: str, data: ProfileUpdate) -> ProfileModel:
        """Create or update a profile."""
        existing = await ProfileService.get_by_user_id(user_id)

        if existing:
            updated = await ProfileService.update(user_id, data)
            return updated if updated else existing
        else:
            create_data = ProfileCreate(**data.model_dump(exclude_unset=True))
            return await ProfileService.create(user_id, create_data)

    @staticmethod
    async def update_avatar(user_id: str, avatar_url: str) -> Optional[ProfileModel]:
        """Update profile avatar URL."""
        result = await Collections.profiles().find_one_and_update(
            {"user_id": user_id},
            {
                "$set": {
                    "avatar_url": avatar_url,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
            return_document=True,
        )

        if result:
            return ProfileService._doc_to_model(result)
        return None

    @staticmethod
    async def mark_completed(user_id: str) -> Optional[ProfileModel]:
        """Mark profile as completed."""
        result = await Collections.profiles().find_one_and_update(
            {"user_id": user_id},
            {
                "$set": {
                    "profile_completed": True,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
            return_document=True,
        )

        if result:
            return ProfileService._doc_to_model(result)
        return None

    @staticmethod
    async def is_completed(user_id: str) -> bool:
        """Check if profile is completed."""
        doc = await Collections.profiles().find_one(
            {"user_id": user_id},
            {"profile_completed": 1}
        )
        return doc.get("profile_completed", False) if doc else False

    @staticmethod
    async def search(query: str, limit: int = 20, exclude_user_id: Optional[str] = None) -> list[ProfileModel]:
        """Search profiles by name, specialization, or clinic."""
        search_filter = {
            "$or": [
                {"first_name": {"$regex": query, "$options": "i"}},
                {"last_name": {"$regex": query, "$options": "i"}},
                {"display_name": {"$regex": query, "$options": "i"}},
                {"specialization": {"$regex": query, "$options": "i"}},
                {"clinic_name": {"$regex": query, "$options": "i"}},
            ]
        }

        if exclude_user_id:
            search_filter["user_id"] = {"$ne": exclude_user_id}

        cursor = Collections.profiles().find(search_filter).limit(limit)
        profiles = []
        async for doc in cursor:
            profiles.append(ProfileService._doc_to_model(doc))

        return profiles

    @staticmethod
    async def get_multiple(user_ids: list[str]) -> list[ProfileModel]:
        """Get multiple profiles by user IDs."""
        cursor = Collections.profiles().find({"user_id": {"$in": user_ids}})
        profiles = []
        async for doc in cursor:
            profiles.append(ProfileService._doc_to_model(doc))
        return profiles
