"""seed super admin from env

Revision ID: 0002_seed_super_admin
Revises: 0001_init
Create Date: 2026-05-03

Reads SUPER_ADMIN_PHONE / SUPER_ADMIN_NAME / SUPER_ADMIN_NPI from environment.
Idempotent — no-ops if user with that phone already exists.
"""
from __future__ import annotations

import os
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002_seed_super_admin"
down_revision: Union[str, None] = "0001_init"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    phone = os.environ.get("SUPER_ADMIN_PHONE", "").strip()
    if not phone:
        return
    name = os.environ.get("SUPER_ADMIN_NAME", "Platform Admin").strip()
    npi = os.environ.get("SUPER_ADMIN_NPI", "0000000001").strip()

    bind = op.get_bind()
    existing = bind.execute(sa.text("SELECT id FROM users WHERE phone = :p"), {"p": phone}).first()
    if existing is not None:
        return

    bind.execute(
        sa.text(
            "INSERT INTO users (phone, full_name, npi_number, role) "
            "VALUES (:phone, :name, :npi, 'super_admin')"
        ),
        {"phone": phone, "name": name, "npi": npi},
    )


def downgrade() -> None:
    phone = os.environ.get("SUPER_ADMIN_PHONE", "").strip()
    if not phone:
        return
    op.execute(sa.text(f"DELETE FROM users WHERE phone = '{phone}' AND role = 'super_admin'"))
