"""per-conversation message sequence numbers for gapless catch-up sync

Revision ID: 0009_message_seq
Revises: 0008_encrypt_transcripts
Create Date: 2026-07-18
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0009_message_seq"
down_revision: Union[str, None] = "0008_encrypt_transcripts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("seq", sa.BigInteger(), nullable=True))
    op.add_column(
        "conversations",
        sa.Column("last_seq", sa.BigInteger(), nullable=False, server_default="0"),
    )

    conn = op.get_bind()
    # Backfill: dense per-conversation ordering by send time (id breaks ties).
    conn.execute(
        sa.text(
            """
            UPDATE messages m
            SET seq = t.rn
            FROM (
                SELECT id,
                       row_number() OVER (
                           PARTITION BY conversation_id ORDER BY created_at, id
                       ) AS rn
                FROM messages
            ) t
            WHERE m.id = t.id
            """
        )
    )
    op.alter_column("messages", "seq", nullable=False)
    conn.execute(
        sa.text(
            """
            UPDATE conversations c
            SET last_seq = COALESCE(
                (SELECT max(seq) FROM messages m WHERE m.conversation_id = c.id), 0
            )
            """
        )
    )
    # Two messages can never share a seq within a conversation.
    op.create_index(
        "uq_messages_conv_seq", "messages", ["conversation_id", "seq"], unique=True
    )


def downgrade() -> None:
    op.drop_index("uq_messages_conv_seq", table_name="messages")
    op.drop_column("messages", "seq")
    op.drop_column("conversations", "last_seq")
