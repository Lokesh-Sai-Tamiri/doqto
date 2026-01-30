"""
Connection API endpoints for network management, blocking, and reporting.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional, List

from middleware.auth import get_current_user, AuthUser
from api.models.connection import (
    ConnectionModel,
    ConnectionCreate,
    NetworkContactModel,
    PendingRequestModel,
    SuggestedContactModel,
    BlockedUserModel,
    BlockUserRequest,
    UserReportModel,
    UserReportCreate,
)
from services.connection_service import ConnectionService

router = APIRouter(prefix="/connections")


# ==================== Network ====================

@router.get("/network", response_model=List[NetworkContactModel])
async def get_network(user: AuthUser = Depends(get_current_user)):
    """Get all accepted connections (network contacts)."""
    return await ConnectionService.get_network(user.user_id)


@router.get("/network/search", response_model=List[NetworkContactModel])
async def search_network(
    q: str = Query(..., min_length=1),
    user: AuthUser = Depends(get_current_user)
):
    """Search within the user's network."""
    return await ConnectionService.search_network(user.user_id, q)


# ==================== Suggestions ====================

@router.get("/suggestions", response_model=List[SuggestedContactModel])
async def get_suggestions(
    limit: int = Query(20, ge=1, le=50),
    user: AuthUser = Depends(get_current_user)
):
    """Get suggested connections."""
    return await ConnectionService.get_suggestions(user.user_id, limit)


# ==================== Pending Requests ====================

@router.get("/pending", response_model=List[PendingRequestModel])
async def get_pending_requests(user: AuthUser = Depends(get_current_user)):
    """Get incoming pending connection requests."""
    return await ConnectionService.get_pending_requests(user.user_id)


@router.get("/sent", response_model=List[str])
async def get_sent_requests(user: AuthUser = Depends(get_current_user)):
    """Get user IDs of sent pending requests."""
    return await ConnectionService.get_sent_requests(user.user_id)


# ==================== Connection Actions ====================

@router.post("/request", response_model=ConnectionModel)
async def send_connection_request(
    data: ConnectionCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Send a connection request."""
    if data.recipient_id == user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot send connection request to yourself"
        )

    connection = await ConnectionService.send_request(
        user.user_id,
        data.recipient_id,
        data.request_message
    )

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot send connection request to this user"
        )

    return connection


@router.post("/{connection_id}/accept", response_model=ConnectionModel)
async def accept_connection_request(
    connection_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Accept a connection request."""
    connection = await ConnectionService.accept_request(connection_id, user.user_id)

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection request not found"
        )

    return connection


@router.post("/{connection_id}/reject")
async def reject_connection_request(
    connection_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Reject a connection request."""
    success = await ConnectionService.reject_request(connection_id, user.user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection request not found"
        )

    return {"success": True}


@router.delete("/{connection_id}")
async def remove_connection(
    connection_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Remove an existing connection."""
    success = await ConnectionService.remove_connection(connection_id, user.user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Connection not found"
        )

    return {"success": True}


@router.get("/status/{other_user_id}", response_model=Optional[ConnectionModel])
async def get_connection_status(
    other_user_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get connection status with another user."""
    return await ConnectionService.get_connection_status(user.user_id, other_user_id)


# ==================== Blocking ====================

@router.post("/users/{user_id}/block", response_model=BlockedUserModel)
async def block_user(
    user_id: str,
    data: Optional[BlockUserRequest] = None,
    user: AuthUser = Depends(get_current_user)
):
    """Block a user."""
    if user_id == user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot block yourself"
        )

    reason = data.reason if data else None
    blocked = await ConnectionService.block_user(user.user_id, user_id, reason)

    if not blocked:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to block user"
        )

    return blocked


@router.delete("/users/{user_id}/block")
async def unblock_user(
    user_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Unblock a user."""
    success = await ConnectionService.unblock_user(user.user_id, user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in blocked list"
        )

    return {"success": True}


@router.get("/users/blocked", response_model=List[BlockedUserModel])
async def get_blocked_users(user: AuthUser = Depends(get_current_user)):
    """Get list of blocked users."""
    return await ConnectionService.get_blocked_users(user.user_id)


# ==================== Reporting ====================

@router.post("/users/{user_id}/report", response_model=UserReportModel)
async def report_user(
    user_id: str,
    data: UserReportCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Report a user for inappropriate behavior."""
    if user_id == user.user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot report yourself"
        )

    # Ensure reported_user_id matches path parameter
    data.reported_user_id = user_id

    return await ConnectionService.report_user(user.user_id, data)
