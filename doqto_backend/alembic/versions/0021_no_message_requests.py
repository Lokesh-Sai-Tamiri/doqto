"""Retire the message-request tier: every conversation is open.

Only colleagues (shared org) and first-degree connections may chat; the
permission layer enforces that on create and on every send, so the access
column no longer gates anything. Pending/declined rows become open so their
history stays visible; sends into them still hit the not_connected check.

Revision ID: 0021_no_message_requests
Revises: 0020_message_hides
Create Date: 2026-09-06
"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "0021_no_message_requests"
down_revision: Union[str, None] = "0020_message_hides"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE conversations SET access = 'open' WHERE access <> 'open'")


def downgrade() -> None:
    pass  # the request tier is gone; nothing to restore
