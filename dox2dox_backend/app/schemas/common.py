from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class IdResponse(BaseModel):
    id: uuid.UUID


class OkResponse(BaseModel):
    ok: bool = True


class Cursor(BaseModel):
    cursor: datetime | None = None
    limit: int = 50
