"""add messages.client_id for idempotent sends

Revision ID: 0007_message_client_id
Revises: 0006_user_profile_fields
Create Date: 2026-07-16
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007_message_client_id"
down_revision: Union[str, None] = "0006_user_profile_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("client_id", sa.String(64), nullable=True))
    # Retries of the same client send must not create a second row.
    op.create_index(
        "uq_messages_conv_client_id",
        "messages",
        ["conversation_id", "client_id"],
        unique=True,
        postgresql_where=sa.text("client_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_messages_conv_client_id", table_name="messages")
    op.drop_column("messages", "client_id")
