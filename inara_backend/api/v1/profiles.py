"""
Profile API endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from typing import Optional

from middleware.auth import get_current_user, AuthUser
from api.models.profile import ProfileModel, ProfileUpdate
from services.profile_service import ProfileService
from services.storage_service import StorageService
from config import settings

router = APIRouter(prefix="/profiles")


@router.get("/me", response_model=ProfileModel)
async def get_my_profile(user: AuthUser = Depends(get_current_user)):
    """Get the current user's profile."""
    profile = await ProfileService.get_by_user_id(user.user_id)

    if not profile:
        # Create a new profile for first-time users
        from api.models.profile import ProfileCreate
        profile = await ProfileService.create(
            user.user_id,
            ProfileCreate(email=user.email, phone=user.phone)
        )

    return profile


@router.put("/me", response_model=ProfileModel)
async def update_my_profile(
    data: ProfileUpdate,
    user: AuthUser = Depends(get_current_user)
):
    """Update the current user's profile."""
    profile = await ProfileService.upsert(user.user_id, data)
    return profile


@router.get("/{user_id}", response_model=ProfileModel)
async def get_profile(
    user_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get a profile by user ID."""
    profile = await ProfileService.get_by_user_id(user_id)

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )

    return profile


@router.post("/me/avatar")
async def get_avatar_upload_url(
    filename: str,
    user: AuthUser = Depends(get_current_user)
):
    """
    Get a presigned URL for uploading an avatar image.

    After uploading to the presigned URL, call PUT /profiles/me with
    the avatar_url to update the profile.
    """
    try:
        upload_url, key, final_url = StorageService.get_avatar_upload_url(
            user.user_id,
            filename
        )

        return {
            "upload_url": upload_url,
            "key": key,
            "final_url": final_url,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate upload URL: {str(e)}"
        )


@router.post("/me/complete", response_model=ProfileModel)
async def mark_profile_completed(user: AuthUser = Depends(get_current_user)):
    """Mark the current user's profile as completed."""
    profile = await ProfileService.mark_completed(user.user_id)

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )

    return profile


@router.get("/me/completed", response_model=bool)
async def is_profile_completed(user: AuthUser = Depends(get_current_user)):
    """Check if the current user's profile is completed."""
    return await ProfileService.is_completed(user.user_id)


@router.get("/search/")
async def search_profiles(
    q: str,
    limit: int = 20,
    user: AuthUser = Depends(get_current_user)
):
    """Search profiles by name, specialization, or clinic."""
    if len(q) < 2:
        return []

    profiles = await ProfileService.search(q, limit, exclude_user_id=user.user_id)
    return profiles
