"""
Connection models for network management, blocking, and reporting.
"""

from datetime import datetime
from typing import Optional, List
from enum import Enum
from pydantic import BaseModel, Field


class ConnectionStatus(str, Enum):
    """Connection request status."""
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    BLOCKED = "blocked"


class ConnectionCreate(BaseModel):
    """Create a connection request."""
    recipient_id: str = Field(..., description="User ID to connect with")
    request_message: Optional[str] = Field(None, max_length=500)


class ConnectionModel(BaseModel):
    """Full connection model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    requester_id: str
    recipient_id: str
    status: ConnectionStatus
    request_message: Optional[str] = None
    created_at: datetime
    accepted_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None
    deleted_by: Optional[str] = None

    class Config:
        from_attributes = True


class NetworkContactModel(BaseModel):
    """Accepted connection with profile information."""
    connection_id: str
    user_id: str
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
    clinic_name: Optional[str] = None
    connected_at: datetime

    class Config:
        from_attributes = True


class PendingRequestModel(BaseModel):
    """Incoming connection request with requester profile."""
    connection_id: str
    requester_id: str
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
    clinic_name: Optional[str] = None
    request_message: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SuggestedContactModel(BaseModel):
    """Suggested user for connection (not yet connected)."""
    user_id: str
    display_name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
    clinic_name: Optional[str] = None
    mutual_connections: int = 0
    # Connection request status if any
    request_status: Optional[ConnectionStatus] = None
    request_sent_by_me: bool = False

    class Config:
        from_attributes = True


class BlockedUserModel(BaseModel):
    """Blocked user record."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    blocker_id: str
    blocked_id: str
    reason: Optional[str] = None
    blocked_at: datetime
    # Populated from profile
    blocked_user: Optional[dict] = None

    class Config:
        from_attributes = True


class BlockUserRequest(BaseModel):
    """Request to block a user."""
    reason: Optional[str] = Field(None, max_length=500)


class UserReportCreate(BaseModel):
    """Create a user report."""
    reported_user_id: str
    reason: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    message_id: Optional[str] = None


class UserReportModel(BaseModel):
    """Full user report model."""
    id: str = Field(..., description="MongoDB ObjectId as string")
    reporter_id: str
    reported_user_id: str
    reason: str
    description: Optional[str] = None
    message_id: Optional[str] = None
    status: str = "pending"  # pending, reviewed, resolved, dismissed
    created_at: datetime
    reviewed_at: Optional[datetime] = None

    class Config:
        from_attributes = True
