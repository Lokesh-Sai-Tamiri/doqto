"""encrypt voice-note transcripts at rest + receipts(user_id) index

Revision ID: 0008_encrypt_transcripts
Revises: 0007_message_client_id
Create Date: 2026-07-16
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0008_encrypt_transcripts"
down_revision: Union[str, None] = "0007_message_client_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("transcript_encrypted", sa.LargeBinary(), nullable=True))

    # Data-migrate: encrypt existing plaintext transcripts (PHI).
    from app.core.security import encrypt_message

    conn = op.get_bind()
    rows = conn.execute(
        sa.text("SELECT id, transcript FROM messages WHERE transcript IS NOT NULL")
    ).all()
    for msg_id, transcript in rows:
        conn.execute(
            sa.text("UPDATE messages SET transcript_encrypted = :blob WHERE id = :id"),
            {"blob": encrypt_message(transcript), "id": msg_id},
        )

    op.drop_column("messages", "transcript")

    # Supports the unread-count anti-join (receipts probed by user).
    op.create_index("idx_message_receipts_user", "message_receipts", ["user_id"])


def downgrade() -> None:
    # Irreversible data transform: restore the column, leave values encrypted-only.
    op.drop_index("idx_message_receipts_user", table_name="message_receipts")
    op.add_column("messages", sa.Column("transcript", sa.Text(), nullable=True))
    op.drop_column("messages", "transcript_encrypted")
