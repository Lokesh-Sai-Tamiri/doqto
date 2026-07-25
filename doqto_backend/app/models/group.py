"""Group models (M5): a Group is 1:1 with a NETWORK conversation (org_id NULL,
type=group). Legacy org group chats (a plain type=group conversation with a
non-NULL org_id and NO groups row) are unaffected and never migrated.

Indexes/constraints are declared on the models — not only in the migration — so
the test harness's Base.metadata.create_all builds them too. The two partial
indexes (one pending join-request per (group, user); active-member role lookup)
are load-bearing for the acceptance tests and must exist in the test DB.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import (
    GroupInviteState,
    GroupJoinPolicy,
    GroupJoinRequestState,
    GroupMemberDmPolicy,
    GroupMemberState,
    GroupPostPolicy,
    GroupRole,
    GroupVisibility,
)
from app.db.postgres import Base
from app.db.tables import Tables


class Group(Base):
    __tablename__ = Tables.GROUPS
    __table_args__ = (
        CheckConstraint(
            "visibility IN ('public', 'private', 'secret')",
            name="ck_groups_visibility",
        ),
        CheckConstraint(
            "join_policy IN ('open', 'request', 'invite_only')",
            name="ck_groups_join_policy",
        ),
        CheckConstraint(
            "post_policy IN ('all_members', 'admins_only')",
            name="ck_groups_post_policy",
        ),
        CheckConstraint(
            "member_dm_policy IN ('open', 'request', 'disabled')",
            name="ck_groups_member_dm_policy",
        ),
        # Discovery ranking: newest/biggest public groups first.
        Index("ix_groups_visibility_member_count", "visibility", text("member_count DESC")),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.CONVERSATIONS}.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    visibility: Mapped[GroupVisibility] = mapped_column(
        String(20),
        default=GroupVisibility.PRIVATE,
        server_default=GroupVisibility.PRIVATE.value,
        nullable=False,
    )
    join_policy: Mapped[GroupJoinPolicy] = mapped_column(
        String(20),
        default=GroupJoinPolicy.REQUEST,
        server_default=GroupJoinPolicy.REQUEST.value,
        nullable=False,
    )
    post_policy: Mapped[GroupPostPolicy] = mapped_column(
        String(20),
        default=GroupPostPolicy.ALL_MEMBERS,
        server_default=GroupPostPolicy.ALL_MEMBERS.value,
        nullable=False,
    )
    member_dm_policy: Mapped[GroupMemberDmPolicy] = mapped_column(
        String(20),
        default=GroupMemberDmPolicy.REQUEST,
        server_default=GroupMemberDmPolicy.REQUEST.value,
        nullable=False,
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=False
    )
    # Provenance only (a group may be seeded from an org); NULL for pure network.
    org_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.ORGANIZATIONS}.id"), nullable=True
    )
    avatar_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    member_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class GroupMember(Base):
    __tablename__ = Tables.GROUP_MEMBERS
    __table_args__ = (
        CheckConstraint(
            "role IN ('owner', 'admin', 'moderator', 'member')",
            name="ck_group_members_role",
        ),
        CheckConstraint(
            "state IN ('active', 'banned', 'left', 'removed')",
            name="ck_group_members_state",
        ),
        Index("ix_group_members_user_state", "user_id", "state"),
        Index(
            "ix_group_members_active_role",
            "group_id",
            "role",
            postgresql_where=text("state = 'active'"),
        ),
    )

    group_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.GROUPS}.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.USERS}.id", ondelete="CASCADE"),
        primary_key=True,
    )
    role: Mapped[GroupRole] = mapped_column(
        String(20),
        default=GroupRole.MEMBER,
        server_default=GroupRole.MEMBER.value,
        nullable=False,
    )
    state: Mapped[GroupMemberState] = mapped_column(
        String(20),
        default=GroupMemberState.ACTIVE,
        server_default=GroupMemberState.ACTIVE.value,
        nullable=False,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    invited_by: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=True
    )


class GroupJoinRequest(Base):
    __tablename__ = Tables.GROUP_JOIN_REQUESTS
    __table_args__ = (
        CheckConstraint(
            "state IN ('pending', 'approved', 'rejected', 'withdrawn')",
            name="ck_group_join_requests_state",
        ),
        # At most one live (pending) request per (group, user).
        Index(
            "uq_group_join_requests_pending",
            "group_id",
            "user_id",
            unique=True,
            postgresql_where=text("state = 'pending'"),
        ),
        Index("ix_group_join_requests_group_state", "group_id", "state"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.GROUPS}.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.USERS}.id", ondelete="CASCADE"),
        nullable=False,
    )
    message: Mapped[str | None] = mapped_column(String(300), nullable=True)
    state: Mapped[GroupJoinRequestState] = mapped_column(
        String(20),
        default=GroupJoinRequestState.PENDING,
        server_default=GroupJoinRequestState.PENDING.value,
        nullable=False,
    )
    decided_by: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=True
    )
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class GroupInvite(Base):
    __tablename__ = Tables.GROUP_INVITES
    __table_args__ = (
        CheckConstraint(
            "state IN ('pending', 'accepted', 'declined', 'revoked', 'expired')",
            name="ck_group_invites_state",
        ),
        UniqueConstraint("token", name="uq_group_invites_token"),
        Index("ix_group_invites_invitee_state", "invitee_id", "state"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    group_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.GROUPS}.id", ondelete="CASCADE"),
        nullable=False,
    )
    inviter_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=False
    )
    # Direct invite → a specific invitee; link invite → NULL + a shareable token.
    invitee_id: Mapped[uuid.UUID | None] = mapped_column(
        PgUUID(as_uuid=True), ForeignKey(f"{Tables.USERS}.id"), nullable=True
    )
    token: Mapped[str | None] = mapped_column(String(64), nullable=True)
    max_uses: Mapped[int | None] = mapped_column(Integer, nullable=True)
    use_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    state: Mapped[GroupInviteState] = mapped_column(
        String(20),
        default=GroupInviteState.PENDING,
        server_default=GroupInviteState.PENDING.value,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
