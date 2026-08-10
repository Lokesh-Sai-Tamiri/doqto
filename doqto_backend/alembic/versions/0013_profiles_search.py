"""public profiles + people search: users.handle/headline, pg_trgm + GIN
indexes for fuzzy full_name/specialty match, btree on state.

Revision ID: 0013_profiles_search
Revises: 0014_notifications
Create Date: 2026-07-25

The 0013 slot was intentionally left for M2 while 0014_notifications shipped
in M1 revising 0012; this migration therefore revises 0014 and becomes the new
head (it does NOT insert between 0012 and 0014).

NOTE (RDS): ``CREATE EXTENSION pg_trgm`` needs superuser or the extension on
the ``rds.extensions`` allow-list. The search service degrades to plain ILIKE
when pg_trgm / similarity() is unavailable (e.g. the test harness, which builds
schema via Base.metadata.create_all and never runs this migration), so the GIN
trgm indexes here are a production ranking/perf optimisation only — never a
correctness dependency.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0013_profiles_search"
down_revision: Union[str, None] = "0014_notifications"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Profile columns. handle is nullable with no backfill — generated lazily
    # on first profile edit; headline is a short public tagline.
    op.add_column("users", sa.Column("handle", sa.String(30), nullable=True))
    op.create_unique_constraint("uq_users_handle", "users", ["handle"])
    op.add_column("users", sa.Column("headline", sa.String(120), nullable=True))

    # Fuzzy search substrate. IF NOT EXISTS so a re-run / shared DB is a no-op.
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.execute(
        "CREATE INDEX ix_users_full_name_trgm ON users "
        "USING gin (full_name gin_trgm_ops)"
    )
    op.execute(
        "CREATE INDEX ix_users_specialty_trgm ON users "
        "USING gin (specialty gin_trgm_ops)"
    )
    op.create_index("ix_users_state", "users", ["state"])


def downgrade() -> None:
    op.drop_index("ix_users_state", table_name="users")
    op.execute("DROP INDEX IF EXISTS ix_users_specialty_trgm")
    op.execute("DROP INDEX IF EXISTS ix_users_full_name_trgm")
    # Leave the pg_trgm extension in place — other objects may depend on it and
    # dropping a shared extension on downgrade is unsafe.
    op.drop_column("users", "headline")
    op.drop_constraint("uq_users_handle", "users", type_="unique")
    op.drop_column("users", "handle")
