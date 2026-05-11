from __future__ import annotations

from pydantic import BaseModel, Field


class RequestOtpIn(BaseModel):
    phone: str = Field(min_length=8, max_length=20)


class VerifyOtpIn(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    code: str = Field(min_length=6, max_length=6)


class RefreshIn(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    is_registered: bool


class RegisterIn(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)
    specialty: str | None = None
    npi_number: str = Field(min_length=10, max_length=10)
