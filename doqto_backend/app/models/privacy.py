"""Per-user privacy settings (M1). Row absent = defaults (see PrivacySnapshot
defaults in relationship_service)."""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, String, func, true
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import Discoverability, DmPolicy, InvitePolicy
from app.db.postgres import Base
from app.db.tables import Tables


class UserPrivacySettings(Base):
    __tablename__ = Tables.USER_PRIVACY_SETTINGS
    __table_args__ = (
        CheckConstraint(
            "invite_policy IN ('everyone', 'second_degree', 'shared_group_or_org', 'nobody')",
            name="ck_user_privacy_invite_policy",
        ),
        CheckConstraint(
            "dm_policy IN ('everyone', 'connections_and_requests', "
            "'connections_only', 'nobody')",
            name="ck_user_privacy_dm_policy",
        ),
        CheckConstraint(
            "discoverability IN ('everyone', 'connections', 'nobody')",
            name="ck_user_privacy_discoverability",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(f"{Tables.USERS}.id", ondelete="CASCADE"),
        primary_key=True,
    )
    invite_policy: Mapped[InvitePolicy] = mapped_column(
        String(24),
        default=InvitePolicy.EVERYONE,
        server_default=InvitePolicy.EVERYONE.value,
        nullable=False,
    )
    dm_policy: Mapped[DmPolicy] = mapped_column(
        String(30),
        default=DmPolicy.CONNECTIONS_AND_REQUESTS,
        server_default=DmPolicy.CONNECTIONS_AND_REQUESTS.value,
        nullable=False,
    )
    discoverability: Mapped[Discoverability] = mapped_column(
        String(20),
        default=Discoverability.EVERYONE,
        server_default=Discoverability.EVERYONE.value,
        nullable=False,
    )
    show_mutual_connections: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default=true(), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
