"""networking substrate: nullable conversation org scope, access tier,
per-member seq receipts, platform-wide direct dedup keys, org network policy

Revision ID: 0011_ws_and_conversation_scope
Revises: 0010_device_tokens
Create Date: 2026-07-25
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011_ws_and_conversation_scope"
down_revision: Union[str, None] = "0010_device_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # -- conversations: NULL org_id = network conversation ----------------
    op.alter_column("conversations", "org_id", nullable=True)
    op.add_column(
        "conversations",
        sa.Column("access", sa.String(20), nullable=False, server_default="open"),
    )
    op.create_check_constraint(
        "ck_conversations_access",
        "conversations",
        "access IN ('open', 'pending_request', 'declined')",
    )
    op.add_column(
        "conversations",
        sa.Column(
            "initiator_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
    )

    # -- conversation_members: seq-based receipts (groups, M3+) -----------
    op.add_column(
        "conversation_members",
        sa.Column("last_read_seq", sa.BigInteger(), nullable=False, server_default="0"),
    )
    op.add_column(
        "conversation_members",
        sa.Column("last_delivered_seq", sa.BigInteger(), nullable=False, server_default="0"),
    )

    # -- direct_conversation_keys: one direct conversation per user pair --
    op.create_table(
        "direct_conversation_keys",
        sa.Column(
            "conversation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("user_lo", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_hi", postgresql.UUID(as_uuid=True), nullable=False),
        sa.UniqueConstraint("user_lo", "user_hi", name="uq_direct_conversation_keys_pair"),
        sa.CheckConstraint("user_lo < user_hi", name="ck_direct_conversation_keys_lo_lt_hi"),
    )
    # Backfill from existing direct conversations. Exactly-2-member direct
    # convs get a key; where an old org-scoped dedup race left duplicate
    # conversations for the same pair, only the earliest (min created_at,
    # id as tiebreak) gets the key — the rest stay functional but keyless.
    # We deliberately do NOT dedup-delete here.
    op.execute(
        sa.text(
            """
            INSERT INTO direct_conversation_keys (conversation_id, user_lo, user_hi)
            SELECT DISTINCT ON (pairs.user_lo, pairs.user_hi)
                   pairs.conversation_id, pairs.user_lo, pairs.user_hi
            FROM (
                -- No min(uuid) aggregate on stock Postgres: canonical uuid
                -- text ordering (fixed-length lowercase hex) == byte ordering.
                SELECT c.id AS conversation_id,
                       c.created_at,
                       MIN(cm.user_id::text)::uuid AS user_lo,
                       MAX(cm.user_id::text)::uuid AS user_hi
                FROM conversations c
                JOIN conversation_members cm ON cm.conversation_id = c.id
                WHERE c.type = 'direct'
                GROUP BY c.id, c.created_at
                HAVING COUNT(*) = 2
            ) pairs
            ORDER BY pairs.user_lo, pairs.user_hi, pairs.created_at ASC,
                     pairs.conversation_id ASC
            """
        )
    )

    # -- organizations: networking kill switch + policy -------------------
    op.add_column(
        "organizations",
        sa.Column(
            "external_networking_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )
    op.add_column(
        "organizations",
        sa.Column(
            "external_dm_policy",
            # 30, not 20: 'connections_and_requests' is 24 chars.
            sa.String(30),
            nullable=False,
            server_default="connections_and_requests",
        ),
    )
    op.create_check_constraint(
        "ck_organizations_external_dm_policy",
        "organizations",
        "external_dm_policy IN ('disabled', 'connections_only', 'connections_and_requests')",
    )
    op.add_column(
        "organizations",
        sa.Column(
            "directory_visibility",
            sa.String(20),
            nullable=False,
            server_default="network",
        ),
    )
    op.create_check_constraint(
        "ck_organizations_directory_visibility",
        "organizations",
        "directory_visibility IN ('org_only', 'network', 'public')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_organizations_directory_visibility", "organizations", type_="check"
    )
    op.drop_column("organizations", "directory_visibility")
    op.drop_constraint(
        "ck_organizations_external_dm_policy", "organizations", type_="check"
    )
    op.drop_column("organizations", "external_dm_policy")
    op.drop_column("organizations", "external_networking_enabled")

    op.drop_table("direct_conversation_keys")

    op.drop_column("conversation_members", "last_delivered_seq")
    op.drop_column("conversation_members", "last_read_seq")

    op.drop_column("conversations", "initiator_id")
    op.drop_constraint("ck_conversations_access", "conversations", type_="check")
    op.drop_column("conversations", "access")
    # NULL-org (network) conversations cannot survive a NOT NULL restore.
    op.execute(sa.text("DELETE FROM conversations WHERE org_id IS NULL"))
    op.alter_column("conversations", "org_id", nullable=False)
