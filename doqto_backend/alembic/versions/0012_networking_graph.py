"""networking graph: invitations, connections (mirrored + pair_id), removal
ledger, blocks, mutes, reports, per-user privacy settings

Revision ID: 0012_networking_graph
Revises: 0011_ws_and_conversation_scope
Create Date: 2026-07-25
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0012_networking_graph"
down_revision: Union[str, None] = "0011_ws_and_conversation_scope"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -- connection_invitations ------------------------------------------ #
    op.create_table(
        "connection_invitations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "sender_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "recipient_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("message", sa.String(300), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "sender_id <> recipient_id", name="ck_connection_invitations_distinct"
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'accepted', 'ignored', 'withdrawn', 'expired')",
            name="ck_connection_invitations_status",
        ),
    )
    op.create_index(
        "uq_connection_invitations_pending",
        "connection_invitations",
        ["sender_id", "recipient_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )
    op.create_index(
        "ix_connection_invitations_recipient_status",
        "connection_invitations",
        ["recipient_id", "status"],
    )
    op.create_index(
        "ix_connection_invitations_sender_status",
        "connection_invitations",
        ["sender_id", "status"],
    )

    # -- connections (mirrored rows, shared pair_id) --------------------- #
    op.create_table(
        "connections",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "connected_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("pair_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "user_id <> connected_user_id", name="ck_connections_distinct"
        ),
    )
    op.create_index("ix_connections_pair_id", "connections", ["pair_id"])
    op.create_index(
        "ix_connections_user_created",
        "connections",
        ["user_id", sa.text("created_at DESC")],
    )

    # -- connection_removals (cooldown ledger) --------------------------- #
    op.create_table(
        "connection_removals",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("pair_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "removed_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("user_a", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_b", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "removed_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_connection_removals_pair", "connection_removals", ["user_a", "user_b"]
    )

    # -- blocks ---------------------------------------------------------- #
    op.create_table(
        "blocks",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "blocker_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "blocked_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_blocks_pair"),
    )
    op.create_index("ix_blocks_blocked", "blocks", ["blocked_id"])

    # -- mutes ----------------------------------------------------------- #
    op.create_table(
        "mutes",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "muted_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint("user_id", "muted_user_id", name="uq_mutes_pair"),
    )

    # -- reports --------------------------------------------------------- #
    op.create_table(
        "reports",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "reporter_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("subject_type", sa.String(20), nullable=False),
        sa.Column("subject_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reason", sa.String(50), nullable=False),
        sa.Column("details", sa.String(1000), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "status IN ('open', 'reviewing', 'actioned', 'dismissed')",
            name="ck_reports_status",
        ),
    )
    op.create_index("ix_reports_status_created", "reports", ["status", "created_at"])

    # -- user_privacy_settings ------------------------------------------ #
    op.create_table(
        "user_privacy_settings",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "invite_policy", sa.String(24), nullable=False, server_default="everyone"
        ),
        sa.Column(
            "dm_policy",
            sa.String(30),
            nullable=False,
            server_default="connections_and_requests",
        ),
        sa.Column(
            "discoverability", sa.String(20), nullable=False, server_default="everyone"
        ),
        sa.Column(
            "show_mutual_connections",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
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
            "invite_policy IN ('everyone', 'second_degree', "
            "'shared_group_or_org', 'nobody')",
            name="ck_user_privacy_invite_policy",
        ),
        sa.CheckConstraint(
            "dm_policy IN ('everyone', 'connections_and_requests', "
            "'connections_only', 'nobody')",
            name="ck_user_privacy_dm_policy",
        ),
        sa.CheckConstraint(
            "discoverability IN ('everyone', 'connections', 'nobody')",
            name="ck_user_privacy_discoverability",
        ),
    )


def downgrade() -> None:
    op.drop_table("user_privacy_settings")
    op.drop_index("ix_reports_status_created", table_name="reports")
    op.drop_table("reports")
    op.drop_table("mutes")
    op.drop_index("ix_blocks_blocked", table_name="blocks")
    op.drop_table("blocks")
    op.drop_index("ix_connection_removals_pair", table_name="connection_removals")
    op.drop_table("connection_removals")
    op.drop_index("ix_connections_user_created", table_name="connections")
    op.drop_index("ix_connections_pair_id", table_name="connections")
    op.drop_table("connections")
    op.drop_index(
        "ix_connection_invitations_sender_status", table_name="connection_invitations"
    )
    op.drop_index(
        "ix_connection_invitations_recipient_status",
        table_name="connection_invitations",
    )
    op.drop_index(
        "uq_connection_invitations_pending", table_name="connection_invitations"
    )
    op.drop_table("connection_invitations")
