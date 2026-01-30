"""
Organization models for hospitals, clinics, departments, and memberships.
"""

from datetime import datetime
from typing import Optional, List
from enum import Enum
from pydantic import BaseModel, Field, EmailStr

from api.models.profile import AddressModel


class OrganizationType(str, Enum):
    """Types of healthcare organizations."""
    HOSPITAL = "hospital"
    CLINIC = "clinic"
    PRACTICE = "practice"
    NETWORK = "network"
    OTHER = "other"


class MemberRole(str, Enum):
    """Roles within an organization."""
    OWNER = "owner"
    ADMIN = "admin"
    HEAD = "head"
    MEMBER = "member"
    STAFF = "staff"
    GUEST = "guest"


class MemberStatus(str, Enum):
    """Membership status."""
    ACTIVE = "active"
    INACTIVE = "inactive"
    PENDING = "pending"
    SUSPENDED = "suspended"


class OrganizationContact(BaseModel):
    """Organization contact information."""
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    website: Optional[str] = None


class OrganizationBase(BaseModel):
    """Base organization fields."""
    name: str = Field(..., max_length=200)
    type: OrganizationType = OrganizationType.OTHER
    description: Optional[str] = Field(None, max_length=1000)
    contact: Optional[OrganizationContact] = None
    address: Optional[AddressModel] = None
    is_public: bool = True


class OrganizationCreate(OrganizationBase):
    """Create a new organization."""
    pass


class OrganizationModel(OrganizationBase):
    """Full organization model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    logo_url: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class OrganizationMembershipModel(BaseModel):
    """Organization membership record."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    organization_id: str
    user_id: str
    department_id: Optional[str] = None
    role: MemberRole = MemberRole.MEMBER
    title: Optional[str] = None
    status: MemberStatus = MemberStatus.ACTIVE
    joined_at: datetime

    class Config:
        from_attributes = True


class MyOrganizationModel(BaseModel):
    """User's organization membership with organization details."""
    membership_id: str
    organization_id: str
    organization_name: str
    organization_type: OrganizationType
    organization_logo_url: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    role: MemberRole
    title: Optional[str] = None
    status: MemberStatus
    department_id: Optional[str] = None
    department_name: Optional[str] = None
    joined_at: datetime
    member_count: int = 0

    class Config:
        from_attributes = True


class DepartmentBase(BaseModel):
    """Base department fields."""
    name: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    color: Optional[str] = Field(None, max_length=20)
    icon: Optional[str] = Field(None, max_length=50)
    display_order: int = 0


class DepartmentCreate(DepartmentBase):
    """Create a new department."""
    head_user_id: Optional[str] = None


class DepartmentModel(DepartmentBase):
    """Full department model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    organization_id: str
    head_user_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ColleagueModel(BaseModel):
    """Organization colleague with profile and membership info."""
    user_id: str
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
    role: MemberRole
    title: Optional[str] = None
    department_id: Optional[str] = None
    department_name: Optional[str] = None
    is_connected: bool = False

    class Config:
        from_attributes = True


class OrganizationInviteCreate(BaseModel):
    """Create an organization invite."""
    department_id: Optional[str] = None
    role: MemberRole = MemberRole.MEMBER
    expires_in_days: int = Field(7, ge=1, le=30)


class OrganizationInviteModel(BaseModel):
    """Full organization invite model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    organization_id: str
    organization_name: Optional[str] = None
    department_id: Optional[str] = None
    department_name: Optional[str] = None
    inviter_id: str
    inviter_name: Optional[str] = None
    role: MemberRole
    invite_code: str
    expires_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class JoinByCodeRequest(BaseModel):
    """Request to join organization by invite code."""
    invite_code: str = Field(..., min_length=6, max_length=20)


class UpdateMemberDepartmentRequest(BaseModel):
    """Request to update member's department."""
    department_id: Optional[str] = None
