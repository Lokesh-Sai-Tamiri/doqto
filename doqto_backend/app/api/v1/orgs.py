from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.constants import RATE_LIMIT_READS_PER_MINUTE
from app.core.dependencies import get_current_user, require_org_admin, require_org_member
from app.core.rate_limit import enforce_rate_limit
from app.core.redis_keys import presence_key
from app.core.routes import ApiRoutes
from app.db.postgres import get_db
from app.db.redis import get_redis
from app.models import OrgMember, Organization, User
from app.schemas.common import OkResponse
from app.schemas.organization import MemberOut, OrgCreateIn, OrgJoinIn, OrgOut
from app.services.file_service import FileService
from app.services.org_service import OrgError, OrgService

router = APIRouter()


async def _to_out(org: Organization, db: AsyncSession) -> OrgOut:
    count = await OrgService.member_count(org_id=org.id, db=db)
    out = OrgOut.model_validate(org)
    out.member_count = count
    return out


@router.post(ApiRoutes.ORGS_CREATE, response_model=OrgOut)
async def create_org(
    body: OrgCreateIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OrgOut:
    try:
        org = await OrgService.create(
            user=user,
            name=body.name,
            address=body.address,
            city=body.city,
            state=body.state,
            practice_type=body.practice_type.value if body.practice_type else None,
            db=db,
        )
    except OrgError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
    return await _to_out(org, db)


@router.get(ApiRoutes.ORGS_MINE, response_model=list[OrgOut])
async def my_orgs(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OrgOut]:
    """Organizations the current user belongs to. Empty list = needs onboarding."""
    rows = await db.execute(
        select(Organization)
        .join(OrgMember, OrgMember.org_id == Organization.id)
        .where(OrgMember.user_id == user.id)
        .order_by(Organization.created_at.desc())
    )
    return [await _to_out(o, db) for o in rows.scalars().all()]


@router.post(ApiRoutes.ORGS_JOIN, response_model=OrgOut)
async def join_org(
    body: OrgJoinIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> OrgOut:
    try:
        org = await OrgService.join(user=user, invite_code=body.invite_code, db=db)
    except OrgError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
    return await _to_out(org, db)


@router.get(ApiRoutes.ORGS_DETAIL, response_model=OrgOut)
async def get_org(
    org_id: uuid.UUID,
    _: object = Depends(require_org_member),
    db: AsyncSession = Depends(get_db),
) -> OrgOut:
    org = await db.scalar(select(Organization).where(Organization.id == org_id))
    if org is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="org_not_found")
    return await _to_out(org, db)


@router.get(ApiRoutes.ORGS_MEMBERS, response_model=list[MemberOut])
async def list_members(
    org_id: uuid.UUID,
    member: OrgMember = Depends(require_org_member),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> list[MemberOut]:
    await enforce_rate_limit(member.user_id, "list_members", RATE_LIMIT_READS_PER_MINUTE)
    rows = await OrgService.members(org_id=org_id, db=db)
    out: list[MemberOut] = []
    for user, m in rows:
        presence = await redis.get(presence_key(user.id))
        out.append(
            MemberOut(
                id=user.id,
                full_name=user.full_name,
                specialty=user.specialty,
                org_role=m.org_role,
                joined_at=m.joined_at,
                presence=presence,
                avatar_color=user.avatar_color,
                avatar_url=user.avatar_url,
                avatar_presigned_url=(
                    await FileService.presigned_url(key=user.avatar_url)
                    if user.avatar_url
                    else None
                ),
            )
        )
    return out


@router.delete(ApiRoutes.ORGS_MEMBER_DETAIL, response_model=OkResponse)
async def remove_member(
    org_id: uuid.UUID,
    user_id: uuid.UUID,
    admin_member=Depends(require_org_admin),
    db: AsyncSession = Depends(get_db),
    current: User = Depends(get_current_user),
) -> OkResponse:
    try:
        await OrgService.remove_member(
            org_id=org_id, target_user_id=user_id, admin=current, db=db
        )
    except OrgError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=str(e)) from e
    return OkResponse()


@router.get(ApiRoutes.ORGS_INVITE_CODE)
async def get_invite_code(
    org_id: uuid.UUID,
    _: object = Depends(require_org_member),
    db: AsyncSession = Depends(get_db),
) -> dict:
    org = await db.scalar(select(Organization).where(Organization.id == org_id))
    if org is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="org_not_found")
    return {"invite_code": org.invite_code}
