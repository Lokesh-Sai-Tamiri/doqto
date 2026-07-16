"""add email + password_hash to users

Revision ID: 0004_user_email_password
Revises: 0003_org_review_notes
Create Date: 2026-05-04

Super-admin signs in via email + password from the Next.js admin panel.
Regular doctors continue to use phone OTP (both columns stay nullable).
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004_user_email_password"
down_revision: Union[str, None] = "0003_org_review_notes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("email", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))
    op.create_index("idx_users_email", "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index("idx_users_email", table_name="users")
    op.drop_column("users", "password_hash")
    op.drop_column("users", "email")
