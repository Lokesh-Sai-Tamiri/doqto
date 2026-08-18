"""account deletion: users.deleted_at tombstone

App Store 5.1.1(v) requires in-app account deletion. A hard DELETE is not
available — most FKs to users.id are RESTRICT and HIPAA §164.316(b)(2)
requires audit rows be retained for six years — so the row stays as a
scrubbed tombstone and this column marks it unusable.

Revision ID: 0018_account_deletion
Revises: 0017_scheduled_messages
Create Date: 2026-08-19
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0018_account_deletion"
down_revision: Union[str, None] = "0017_scheduled_messages"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    # Live-user lookups (directory, search) filter on this constantly.
    op.create_index(
        "ix_users_deleted_at",
        "users",
        ["deleted_at"],
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_users_deleted_at", table_name="users")
    op.drop_column("users", "deleted_at")
