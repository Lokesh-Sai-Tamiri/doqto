"""add review_notes to organizations

Revision ID: 0003_org_review_notes
Revises: 0002_seed_super_admin
Create Date: 2026-05-04

Super-admin can record a rejection reason or approval note on any org.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003_org_review_notes"
down_revision: Union[str, None] = "0002_seed_super_admin"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("organizations", sa.Column("review_notes", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("organizations", "review_notes")
