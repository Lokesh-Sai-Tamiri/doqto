"""init schema

Revision ID: 0001_init
Revises:
Create Date: 2026-05-03

"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_init"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto"')

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("phone", sa.String(20), nullable=False, unique=True),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("specialty", sa.String(100)),
        sa.Column("npi_number", sa.CHAR(10), nullable=False, unique=True),
        sa.Column("role", sa.String(20), nullable=False, server_default="doctor"),
        sa.Column("avatar_color", sa.String(7)),
        sa.Column("last_seen_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_users_phone", "users", ["phone"])
    op.create_index("idx_users_npi", "users", ["npi_number"])

    op.create_table(
        "organizations",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("address", sa.Text),
        sa.Column("city", sa.String(100)),
        sa.Column("state", sa.CHAR(2)),
        sa.Column("practice_type", sa.String(50)),
        sa.Column("invite_code", sa.CHAR(9), nullable=False, unique=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("verified_at", sa.DateTime(timezone=True)),
        sa.Column("verified_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_orgs_invite_code", "organizations", ["invite_code"])
    op.create_index("idx_orgs_status", "organizations", ["status"])

    op.create_table(
        "org_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column(
            "org_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("org_role", sa.String(20), nullable=False, server_default="doctor"),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("org_id", "user_id"),
    )
    op.create_index("idx_org_members_org", "org_members", ["org_id"])
    op.create_index("idx_org_members_user", "org_members", ["user_id"])

    op.create_table(
        "conversations",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("org_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("type", sa.String(10), nullable=False),
        sa.Column("name", sa.String(100)),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("disappear_after_sec", sa.Integer),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_convos_org", "conversations", ["org_id"])

    op.create_table(
        "conversation_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column(
            "conversation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("last_read_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("conversation_id", "user_id"),
    )
    op.create_index("idx_convo_members_convo", "conversation_members", ["conversation_id"])
    op.create_index("idx_convo_members_user", "conversation_members", ["user_id"])

    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("conversation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("conversations.id"), nullable=False),
        sa.Column("sender_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("content_encrypted", sa.LargeBinary),
        sa.Column("s3_key", sa.Text),
        sa.Column("file_name", sa.String(255)),
        sa.Column("file_size_bytes", sa.Integer),
        sa.Column("voice_duration_sec", sa.Integer),
        sa.Column("transcript", sa.Text),
        sa.Column("transcript_status", sa.String(20), nullable=False, server_default="none"),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column("is_deleted", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index(
        "idx_messages_convo", "messages", ["conversation_id", sa.text("created_at DESC")]
    )
    op.create_index("idx_messages_sender", "messages", ["sender_id"])
    op.create_index(
        "idx_messages_expires",
        "messages",
        ["expires_at"],
        postgresql_where=sa.text("expires_at IS NOT NULL"),
    )

    op.create_table(
        "message_receipts",
        sa.Column(
            "message_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), primary_key=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True)),
        sa.Column("read_at", sa.DateTime(timezone=True)),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("resource_type", sa.String(50)),
        sa.Column("resource_id", postgresql.UUID(as_uuid=True)),
        sa.Column("ip_address", postgresql.INET),
        sa.Column("user_agent", sa.Text),
        sa.Column("metadata", postgresql.JSONB),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_audit_user", "audit_logs", ["user_id", sa.text("created_at DESC")])
    op.create_index("idx_audit_action", "audit_logs", ["action", sa.text("created_at DESC")])


def downgrade() -> None:
    op.drop_table("audit_logs")
    op.drop_table("message_receipts")
    op.drop_table("messages")
    op.drop_table("conversation_members")
    op.drop_table("conversations")
    op.drop_table("org_members")
    op.drop_table("organizations")
    op.drop_table("users")
