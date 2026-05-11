from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CHAR, DateTime, SmallInteger, String, func
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.enums import UserRole
from app.db.postgres import Base
from app.db.tables import Tables


class User(Base):
    __tablename__ = Tables.USERS

    id: Mapped[uuid.UUID] = mapped_column(
        PgUUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid()
    )
    phone: Mapped[str] = mapped_column(String(20), unique=True, nullable=False, index=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    specialty: Mapped[str | None] = mapped_column(String(100), nullable=True)
    npi_number: Mapped[str] = mapped_column(CHAR(10), unique=True, nullable=False, index=True)
    role: Mapped[UserRole] = mapped_column(String(20), default=UserRole.DOCTOR, nullable=False)
    avatar_color: Mapped[str | None] = mapped_column(String(7), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(500), nullable=True)
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    state: Mapped[str | None] = mapped_column(String(120), nullable=True)
    years_of_experience: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    skills: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, server_default="{}", default=list
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
