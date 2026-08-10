"""scheduled messages: long-press send → deliver later

One row per queued text message. Content encrypted at rest like live
messages; `scheduled_at` is the resolved UTC instant, `timezone` the IANA
zone the sender picked (display only).

Revision ID: 0017_scheduled_messages
Revises: 0016_groups_invite_only
Create Date: 2026-08-08
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0017_scheduled_messages"
down_revision: Union[str, None] = "0016_groups_invite_only"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "scheduled_messages",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "conversation_id",
            UUID(as_uuid=True),
            sa.ForeignKey("conversations.id"),
            nullable=False,
        ),
        sa.Column("sender_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("content_encrypted", sa.LargeBinary(), nullable=False),
        sa.Column("timezone", sa.String(64), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("error", sa.String(100), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index(
        "ix_scheduled_messages_conversation_id", "scheduled_messages", ["conversation_id"]
    )
    op.create_index("ix_scheduled_messages_sender_id", "scheduled_messages", ["sender_id"])
    op.create_index("ix_scheduled_messages_scheduled_at", "scheduled_messages", ["scheduled_at"])


def downgrade() -> None:
    op.drop_table("scheduled_messages")
