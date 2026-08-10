"""groups (1:1 with a network conversation), members, join requests, invites

A Group is a `groups` row paired 1:1 with a NETWORK conversation (org_id NULL,
type=group). Legacy org group chats (plain type=group conversations with a
non-NULL org_id and NO groups row) are unaffected and NOT migrated.

Revision ID: 0015_groups
Revises: 0013_profiles_search
Create Date: 2026-07-25
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0015_groups"
down_revision: Union[str, None] = "0013_profiles_search"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -- groups ---------------------------------------------------------- #
    op.create_table(
        "groups",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "conversation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("description", sa.String(1000), nullable=True),
        sa.Column("visibility", sa.String(20), nullable=False, server_default="private"),
        sa.Column("join_policy", sa.String(20), nullable=False, server_default="request"),
        sa.Column("post_policy", sa.String(20), nullable=False, server_default="all_members"),
        sa.Column(
            "member_dm_policy", sa.String(20), nullable=False, server_default="request"
        ),
        sa.Column(
            "owner_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "org_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("organizations.id"),
            nullable=True,
        ),
        sa.Column("avatar_url", sa.String(1024), nullable=True),
        sa.Column("member_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "visibility IN ('public', 'private', 'secret')", name="ck_groups_visibility"
        ),
        sa.CheckConstraint(
            "join_policy IN ('open', 'request', 'invite_only')",
            name="ck_groups_join_policy",
        ),
        sa.CheckConstraint(
            "post_policy IN ('all_members', 'admins_only')", name="ck_groups_post_policy"
        ),
        sa.CheckConstraint(
            "member_dm_policy IN ('open', 'request', 'disabled')",
            name="ck_groups_member_dm_policy",
        ),
    )
    op.create_index(
        "ix_groups_visibility_member_count",
        "groups",
        ["visibility", sa.text("member_count DESC")],
    )

    # -- group_members --------------------------------------------------- #
    op.create_table(
        "group_members",
        sa.Column(
            "group_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("groups.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("role", sa.String(20), nullable=False, server_default="member"),
        sa.Column("state", sa.String(20), nullable=False, server_default="active"),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "invited_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.CheckConstraint(
            "role IN ('owner', 'admin', 'moderator', 'member')",
            name="ck_group_members_role",
        ),
        sa.CheckConstraint(
            "state IN ('active', 'banned', 'left', 'removed')",
            name="ck_group_members_state",
        ),
    )
    op.create_index("ix_group_members_user_state", "group_members", ["user_id", "state"])
    op.create_index(
        "ix_group_members_active_role",
        "group_members",
        ["group_id", "role"],
        postgresql_where=sa.text("state = 'active'"),
    )

    # -- group_join_requests --------------------------------------------- #
    op.create_table(
        "group_join_requests",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "group_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("groups.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("message", sa.String(300), nullable=True),
        sa.Column("state", sa.String(20), nullable=False, server_default="pending"),
        sa.Column(
            "decided_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "state IN ('pending', 'approved', 'rejected', 'withdrawn')",
            name="ck_group_join_requests_state",
        ),
    )
    op.create_index(
        "uq_group_join_requests_pending",
        "group_join_requests",
        ["group_id", "user_id"],
        unique=True,
        postgresql_where=sa.text("state = 'pending'"),
    )
    op.create_index(
        "ix_group_join_requests_group_state",
        "group_join_requests",
        ["group_id", "state"],
    )

    # -- group_invites --------------------------------------------------- #
    op.create_table(
        "group_invites",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "group_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("groups.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "inviter_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "invitee_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column("token", sa.String(64), nullable=True),
        sa.Column("max_uses", sa.Integer(), nullable=True),
        sa.Column("use_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("state", sa.String(20), nullable=False, server_default="pending"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "state IN ('pending', 'accepted', 'declined', 'revoked', 'expired')",
            name="ck_group_invites_state",
        ),
        sa.UniqueConstraint("token", name="uq_group_invites_token"),
    )
    op.create_index(
        "ix_group_invites_invitee_state", "group_invites", ["invitee_id", "state"]
    )


def downgrade() -> None:
    op.drop_index("ix_group_invites_invitee_state", table_name="group_invites")
    op.drop_table("group_invites")
    op.drop_index(
        "ix_group_join_requests_group_state", table_name="group_join_requests"
    )
    op.drop_index(
        "uq_group_join_requests_pending", table_name="group_join_requests"
    )
    op.drop_table("group_join_requests")
    op.drop_index("ix_group_members_active_role", table_name="group_members")
    op.drop_index("ix_group_members_user_state", table_name="group_members")
    op.drop_table("group_members")
    op.drop_index("ix_groups_visibility_member_count", table_name="groups")
    op.drop_table("groups")
