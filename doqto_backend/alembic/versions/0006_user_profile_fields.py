"""add profile fields to users (avatar_url, bio, city, state, years_of_experience, skills)

Revision ID: 0006_user_profile_fields
Revises: 0005_seed_admin_creds
Create Date: 2026-05-10
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006_user_profile_fields"
down_revision: Union[str, None] = "0005_seed_admin_creds"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("avatar_url", sa.String(1024), nullable=True))
    op.add_column("users", sa.Column("bio", sa.String(500), nullable=True))
    op.add_column("users", sa.Column("city", sa.String(120), nullable=True))
    op.add_column("users", sa.Column("state", sa.String(120), nullable=True))
    op.add_column("users", sa.Column("years_of_experience", sa.SmallInteger(), nullable=True))
    op.add_column(
        "users",
        sa.Column(
            "skills",
            postgresql.ARRAY(sa.String(40)),
            nullable=False,
            server_default="{}",
        ),
    )
    op.create_check_constraint(
        "ck_users_years_of_experience_range",
        "users",
        "years_of_experience IS NULL OR (years_of_experience >= 0 AND years_of_experience <= 80)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_years_of_experience_range", "users", type_="check")
    op.drop_column("users", "skills")
    op.drop_column("users", "years_of_experience")
    op.drop_column("users", "state")
    op.drop_column("users", "city")
    op.drop_column("users", "bio")
    op.drop_column("users", "avatar_url")
