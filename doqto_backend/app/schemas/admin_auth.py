from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field


class AdminLoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=200)
