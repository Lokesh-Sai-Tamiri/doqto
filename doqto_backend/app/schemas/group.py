from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.core.constants import (
    GROUP_DESCRIPTION_MAX_LEN,
    GROUP_JOIN_REQUEST_MESSAGE_MAX_LEN,
    GROUP_NAME_MAX_LEN,
)
from app.core.enums import (
    GroupJoinPolicy,
    GroupMemberDmPolicy,
    GroupMemberState,
    GroupPostPolicy,
    GroupRole,
    GroupVisibility,
)
from app.schemas.common import ORMModel


class GroupCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=GROUP_NAME_MAX_LEN)
    description: str | None = Field(default=None, max_length=GROUP_DESCRIPTION_MAX_LEN)
    visibility: GroupVisibility = GroupVisibility.PRIVATE
    join_policy: GroupJoinPolicy = GroupJoinPolicy.REQUEST
    post_policy: GroupPostPolicy = GroupPostPolicy.ALL_MEMBERS
    member_dm_policy: GroupMemberDmPolicy = GroupMemberDmPolicy.REQUEST
    org_id: uuid.UUID | None = None


class GroupUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=GROUP_NAME_MAX_LEN)
    description: str | None = Field(default=None, max_length=GROUP_DESCRIPTION_MAX_LEN)
    visibility: GroupVisibility | None = None
    join_policy: GroupJoinPolicy | None = None
    post_policy: GroupPostPolicy | None = None
    member_dm_policy: GroupMemberDmPolicy | None = None
    avatar_url: str | None = Field(default=None, max_length=1024)


class GroupOut(ORMModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    name: str
    description: str | None
    visibility: GroupVisibility
    join_policy: GroupJoinPolicy
    post_policy: GroupPostPolicy
    member_dm_policy: GroupMemberDmPolicy
    owner_id: uuid.UUID
    org_id: uuid.UUID | None
    avatar_url: str | None
    member_count: int
    created_at: datetime
    updated_at: datetime
    # Populated by the router for the requesting user.
    my_role: GroupRole | None = None
    my_state: GroupMemberState | None = None


class GroupCardOut(BaseModel):
    """Discovery card — visibility-redacted (§6.4). Private groups drop
    description/join_policy for non-members; secret groups are never listed."""

    id: uuid.UUID
    name: str
    visibility: GroupVisibility
    member_count: int
    avatar_url: str | None = None
    description: str | None = None
    join_policy: GroupJoinPolicy | None = None
    my_role: GroupRole | None = None
    my_state: GroupMemberState | None = None


class JoinRequestCreateIn(BaseModel):
    message: str | None = Field(
        default=None, max_length=GROUP_JOIN_REQUEST_MESSAGE_MAX_LEN
    )


class JoinRequestOut(ORMModel):
    id: uuid.UUID
    group_id: uuid.UUID
    user_id: uuid.UUID
    message: str | None
    state: str
    created_at: datetime


class InviteCreateIn(BaseModel):
    """Either a direct invite (user_id) OR a shareable link (link=true)."""

    user_id: uuid.UUID | None = None
    link: bool = False
    max_uses: int | None = Field(default=None, ge=1)
    expires_at: datetime | None = None


class GroupInviteOut(ORMModel):
    id: uuid.UUID
    group_id: uuid.UUID
    inviter_id: uuid.UUID
    invitee_id: uuid.UUID | None
    token: str | None
    max_uses: int | None
    use_count: int
    expires_at: datetime | None
    state: str
    created_at: datetime


class MemberRoleUpdateIn(BaseModel):
    role: GroupRole


class TransferOwnershipIn(BaseModel):
    user_id: uuid.UUID


class GroupMemberOut(BaseModel):
    user_id: uuid.UUID
    full_name: str
    role: GroupRole
    state: GroupMemberState
    specialty: str | None = None
    avatar_color: str | None = None
    avatar_url: str | None = None


class JoinResultOut(BaseModel):
    result: str  # 'joined' | 'requested'
    group_id: uuid.UUID
