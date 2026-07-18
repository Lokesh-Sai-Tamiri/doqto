from __future__ import annotations

from pydantic import BaseModel, Field

from app.core.enums import DevicePlatform


class PushTokenIn(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    platform: DevicePlatform


class PushTokenDeleteIn(BaseModel):
    token: str = Field(min_length=1, max_length=512)
