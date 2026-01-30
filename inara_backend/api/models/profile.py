"""
Profile models for API requests and responses.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, EmailStr


class AddressModel(BaseModel):
    """Address sub-document model."""
    line1: Optional[str] = None
    line2: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    country: Optional[str] = None


class ProfileBase(BaseModel):
    """Base profile fields shared between create and update."""
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    display_name: Optional[str] = Field(None, max_length=200)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=20)
    doctor_id: Optional[str] = Field(None, max_length=50)
    specialization: Optional[str] = Field(None, max_length=200)
    clinic_name: Optional[str] = Field(None, max_length=200)
    years_of_experience: Optional[int] = Field(None, ge=0, le=100)
    address: Optional[AddressModel] = None
    bio: Optional[str] = Field(None, max_length=1000)


class ProfileCreate(ProfileBase):
    """Profile creation model - requires user_id from auth."""
    pass


class ProfileUpdate(ProfileBase):
    """Profile update model - all fields optional."""
    avatar_url: Optional[str] = None
    profile_completed: Optional[bool] = None


class ProfileModel(ProfileBase):
    """Full profile model returned from API."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    user_id: str = Field(..., description="Supabase auth user ID")
    avatar_url: Optional[str] = None
    profile_completed: bool = False
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ProfileSummary(BaseModel):
    """Minimal profile info for lists and references."""
    user_id: str
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
