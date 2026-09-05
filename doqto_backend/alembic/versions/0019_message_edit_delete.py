"""message edit (5 min, transparent history) + delete (3 min, tombstone)

messages.edited_at / deleted_at, plus message_edits holding every superseded
version (encrypted like bodies).

Revision ID: 0019_message_edit_delete
Revises: 0018_account_deletion
Create Date: 2026-09-05
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0019_message_edit_delete"
down_revision: Union[str, None] = "0018_account_deletion"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("messages", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "message_edits",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "message_id",
            UUID(as_uuid=True),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("content_encrypted", sa.LargeBinary(), nullable=False),
        sa.Column(
            "replaced_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("ix_message_edits_message_id", "message_edits", ["message_id"])


def downgrade() -> None:
    op.drop_table("message_edits")
    op.drop_column("messages", "deleted_at")
    op.drop_column("messages", "edited_at")
