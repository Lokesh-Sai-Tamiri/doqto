"""
Organization API endpoints for hospitals, clinics, departments, and memberships.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional, List

from middleware.auth import get_current_user, AuthUser
from api.models.organization import (
    OrganizationModel,
    OrganizationCreate,
    MyOrganizationModel,
    DepartmentModel,
    DepartmentCreate,
    ColleagueModel,
    OrganizationInviteModel,
    OrganizationInviteCreate,
    JoinByCodeRequest,
    UpdateMemberDepartmentRequest,
)
from services.organization_service import OrganizationService
from services.storage_service import StorageService

router = APIRouter(prefix="/organizations")


# ==================== Organizations ====================

@router.get("/my", response_model=List[MyOrganizationModel])
async def get_my_organizations(user: AuthUser = Depends(get_current_user)):
    """Get all organizations the current user belongs to."""
    return await OrganizationService.get_my_organizations(user.user_id)


@router.get("/{org_id}", response_model=OrganizationModel)
async def get_organization(
    org_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get organization details."""
    org = await OrganizationService.get_organization(org_id, user.user_id)

    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found or access denied"
        )

    return org


@router.post("", response_model=OrganizationModel)
async def create_organization(
    data: OrganizationCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Create a new organization."""
    return await OrganizationService.create_organization(user.user_id, data)


@router.delete("/{org_id}/leave")
async def leave_organization(
    org_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Leave an organization."""
    success = await OrganizationService.leave_organization(org_id, user.user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot leave organization. You may be the owner or not a member."
        )

    return {"success": True}


# ==================== Departments ====================

@router.get("/{org_id}/departments", response_model=List[DepartmentModel])
async def get_departments(
    org_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get all departments in an organization."""
    return await OrganizationService.get_departments(org_id, user.user_id)


@router.post("/{org_id}/departments", response_model=DepartmentModel)
async def create_department(
    org_id: str,
    data: DepartmentCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Create a new department (admin/owner only)."""
    dept = await OrganizationService.create_department(org_id, user.user_id, data)

    if not dept:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied or organization not found"
        )

    return dept


# ==================== Colleagues ====================

@router.get("/{org_id}/colleagues", response_model=List[ColleagueModel])
async def get_colleagues(
    org_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get all colleagues in an organization."""
    return await OrganizationService.get_colleagues(org_id, user.user_id)


@router.get("/{org_id}/colleagues/search", response_model=List[ColleagueModel])
async def search_colleagues(
    org_id: str,
    q: str = Query(..., min_length=1),
    user: AuthUser = Depends(get_current_user)
):
    """Search colleagues by name or specialization."""
    return await OrganizationService.search_colleagues(org_id, user.user_id, q)


@router.get("/{org_id}/departments/{dept_id}/colleagues", response_model=List[ColleagueModel])
async def get_colleagues_by_department(
    org_id: str,
    dept_id: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get colleagues in a specific department."""
    return await OrganizationService.get_colleagues_by_department(org_id, dept_id, user.user_id)


# ==================== Invites ====================

@router.get("/invites/pending", response_model=List[OrganizationInviteModel])
async def get_my_pending_invites(user: AuthUser = Depends(get_current_user)):
    """Get pending organization invites for the current user."""
    return await OrganizationService.get_my_pending_invites(user.user_id)


@router.post("/{org_id}/invites", response_model=OrganizationInviteModel)
async def create_invite(
    org_id: str,
    data: OrganizationInviteCreate,
    user: AuthUser = Depends(get_current_user)
):
    """Create an organization invite (admin/owner only)."""
    invite = await OrganizationService.create_invite(org_id, user.user_id, data)

    if not invite:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied or organization not found"
        )

    return invite


@router.post("/invites/join", response_model=MyOrganizationModel)
async def join_by_invite_code(
    data: JoinByCodeRequest,
    user: AuthUser = Depends(get_current_user)
):
    """Join an organization using an invite code."""
    membership = await OrganizationService.join_by_code(user.user_id, data.invite_code)

    if not membership:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid or expired invite code"
        )

    return membership


# ==================== Memberships ====================

@router.patch("/memberships/{membership_id}/department")
async def update_member_department(
    membership_id: str,
    data: UpdateMemberDepartmentRequest,
    user: AuthUser = Depends(get_current_user)
):
    """Update a member's department assignment."""
    success = await OrganizationService.update_member_department(
        membership_id,
        user.user_id,
        data.department_id
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Membership not found or not yours"
        )

    return {"success": True}


# ==================== Logo Upload ====================

@router.post("/{org_id}/logo")
async def get_logo_upload_url(
    org_id: str,
    filename: str,
    user: AuthUser = Depends(get_current_user)
):
    """Get a presigned URL for uploading an organization logo."""
    # Verify admin/owner access
    org = await OrganizationService.get_organization(org_id, user.user_id)
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Organization not found or access denied"
        )

    try:
        upload_url, key, final_url = StorageService.get_org_logo_upload_url(
            org_id,
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
