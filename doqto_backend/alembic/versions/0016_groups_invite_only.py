"""groups are invite-only: drop discovery + join requests

Groups are no longer discoverable and cannot be joined on request — an invite
is the only way in. That retires `group_join_requests` entirely along with the
two columns that only ever fed discovery and the join state machine
(`visibility`, `join_policy`).

Revision ID: 0016_groups_invite_only
Revises: 0015_groups
Create Date: 2026-07-26
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0016_groups_invite_only"
down_revision: Union[str, None] = "0015_groups"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_table("group_join_requests")

    op.drop_index("ix_groups_visibility_member_count", table_name="groups")
    op.drop_constraint("ck_groups_visibility", "groups", type_="check")
    op.drop_constraint("ck_groups_join_policy", "groups", type_="check")
    op.drop_column("groups", "visibility")
    op.drop_column("groups", "join_policy")


def downgrade() -> None:
    # Restores the shape, not the data: every group comes back private and
    # invite-only, and past join requests are gone for good.
    op.add_column(
        "groups",
        sa.Column(
            "visibility",
            sa.String(20),
            nullable=False,
            server_default="private",
        ),
    )
    op.add_column(
        "groups",
        sa.Column(
            "join_policy",
            sa.String(20),
            nullable=False,
            server_default="invite_only",
        ),
    )
    op.create_check_constraint(
        "ck_groups_visibility", "groups", "visibility IN ('public', 'private', 'secret')"
    )
    op.create_check_constraint(
        "ck_groups_join_policy", "groups", "join_policy IN ('open', 'request', 'invite_only')"
    )
    op.create_index(
        "ix_groups_visibility_member_count",
        "groups",
        ["visibility", sa.text("member_count DESC")],
    )
    op.create_table(
        "group_join_requests",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "group_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("groups.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("message", sa.String(300), nullable=True),
        sa.Column("state", sa.String(20), nullable=False, server_default="pending"),
        sa.Column(
            "decided_by",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column("decided_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
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
        "ix_group_join_requests_group_state", "group_join_requests", ["group_id", "state"]
    )
