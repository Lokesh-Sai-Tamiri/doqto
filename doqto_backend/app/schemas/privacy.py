from __future__ import annotations

from pydantic import BaseModel

from app.core.enums import Discoverability, DmPolicy, InvitePolicy
from app.schemas.common import ORMModel


class PrivacyOut(ORMModel):
    invite_policy: InvitePolicy
    dm_policy: DmPolicy
    discoverability: Discoverability
    show_mutual_connections: bool


class PrivacyPatch(BaseModel):
    invite_policy: InvitePolicy | None = None
    dm_policy: DmPolicy | None = None
    discoverability: Discoverability | None = None
    show_mutual_connections: bool | None = None
