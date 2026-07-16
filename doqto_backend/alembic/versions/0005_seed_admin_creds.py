"""backfill super-admin email + password hash

Revision ID: 0005_seed_super_admin_credentials
Revises: 0004_user_email_password
Create Date: 2026-05-04

Reads SUPER_ADMIN_EMAIL + SUPER_ADMIN_PASSWORD from env and sets them on the
already-seeded super-admin row (identified by SUPER_ADMIN_PHONE). Idempotent —
if either env var is missing we skip; if the row already has credentials we
overwrite them so rotating the password is a one-command operation
(``alembic downgrade -1 && alembic upgrade head``).
"""
from __future__ import annotations

import os
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from passlib.context import CryptContext

revision: str = "0005_seed_admin_creds"
down_revision: Union[str, None] = "0004_user_email_password"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def upgrade() -> None:
    phone = os.environ.get("SUPER_ADMIN_PHONE", "").strip()
    email = os.environ.get("SUPER_ADMIN_EMAIL", "").strip().lower()
    password = os.environ.get("SUPER_ADMIN_PASSWORD", "")
    if not phone or not email or not password:
        return
    bind = op.get_bind()
    bind.execute(
        sa.text(
            "UPDATE users SET email = :email, password_hash = :hash "
            "WHERE phone = :phone AND role = 'super_admin'"
        ),
        {"email": email, "hash": _pwd.hash(password), "phone": phone},
    )


def downgrade() -> None:
    phone = os.environ.get("SUPER_ADMIN_PHONE", "").strip()
    if not phone:
        return
    op.execute(
        sa.text(
            f"UPDATE users SET email = NULL, password_hash = NULL "
            f"WHERE phone = '{phone}' AND role = 'super_admin'"
        )
    )
