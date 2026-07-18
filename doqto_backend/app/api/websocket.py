from __future__ import annotations

import asyncio
import time
import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from redis.asyncio import Redis
from sqlalchemy import select

from app.api.ws_manager import ws_manager
from app.core.constants import (
    PRESENCE_AWAY_TTL_SECONDS,
    PRESENCE_ONLINE_TTL_SECONDS,
    WS_HEARTBEAT_TIMEOUT_SECONDS,
)
from app.core.enums import JwtTokenType, PresenceStatus, WsEventClient, WsEventServer
from app.core.redis_keys import presence_key
from app.core.security import TokenError, decode_token
from app.db.postgres import SessionLocal
from app.db.redis import get_redis
from app.models import OrgMember
from app.services.message_service import MessageService

router = APIRouter()

# Typing fires per keystroke — cache conversation membership briefly so we
# don't hit Postgres on every event.
# ponytail: in-process TTL dict; move to Redis if membership churn matters.
_MEMBERS_TTL_SEC = 60
_members_cache: dict[str, tuple[float, list[uuid.UUID]]] = {}


async def _cached_member_ids(conversation_id: str) -> list[uuid.UUID]:
    hit = _members_cache.get(conversation_id)
    now = time.monotonic()
    if hit is not None and hit[0] > now:
        return hit[1]
    async with SessionLocal() as db:
        ids = await MessageService.member_ids(
            conversation_id=uuid.UUID(conversation_id), db=db
        )
    _members_cache[conversation_id] = (now + _MEMBERS_TTL_SEC, ids)
    return ids


async def _authorize(token: str, org_id: uuid.UUID) -> uuid.UUID:
    payload = decode_token(token, JwtTokenType.ACCESS)
    user_id = uuid.UUID(payload["sub"])
    async with SessionLocal() as db:
        member = await db.scalar(
            select(OrgMember).where(OrgMember.org_id == org_id, OrgMember.user_id == user_id)
        )
    if member is None:
        raise TokenError("not_an_org_member")
    return user_id


@router.websocket("/ws/{org_id}")
async def websocket_endpoint(websocket: WebSocket, org_id: uuid.UUID) -> None:
    # Auth-frame only: the token must arrive in a first `auth` frame.
    # A `?token=` query string is never read (query strings end up in
    # proxy/access logs — M1).
    await websocket.accept()
    try:
        first = await asyncio.wait_for(websocket.receive_json(), timeout=5)
        if first.get("type") != "auth" or not isinstance(first.get("token"), str):
            raise TokenError("missing_auth_frame")
        user_id = await _authorize(first["token"], org_id)
    except Exception:
        await websocket.close(code=4401)
        return
    await ws_manager.connect(org_id, user_id, websocket)
    redis: Redis = await get_redis()
    await redis.setex(presence_key(user_id), PRESENCE_ONLINE_TTL_SECONDS, PresenceStatus.ONLINE.value)
    await ws_manager.publish_org(
        org_id,
        WsEventServer.PRESENCE_UPDATE,
        {"user_id": str(user_id), "status": PresenceStatus.ONLINE.value},
    )

    try:
        while True:
            try:
                # Zombie reaper: a client silent past 2 missed heartbeats is dead.
                msg = await asyncio.wait_for(
                    websocket.receive_json(), timeout=WS_HEARTBEAT_TIMEOUT_SECONDS
                )
            except TimeoutError:
                try:
                    await websocket.close(code=1001)  # going away
                except Exception:
                    pass  # socket already dead
                break  # finally handles presence + cleanup
            msg_type = msg.get("type")
            if msg_type == WsEventClient.HEARTBEAT.value:
                await redis.setex(
                    presence_key(user_id), PRESENCE_ONLINE_TTL_SECONDS, PresenceStatus.ONLINE.value
                )
                # Direct ack (no fanout) — the client's liveness signal.
                await websocket.send_json(
                    {"type": WsEventServer.HEARTBEAT_ACK.value, "data": {}}
                )
            elif msg_type in (WsEventClient.TYPING_START.value, WsEventClient.TYPING_STOP.value):
                event = (
                    WsEventServer.TYPING_START
                    if msg_type == WsEventClient.TYPING_START.value
                    else WsEventServer.TYPING_STOP
                )
                conv_id = msg.get("conversation_id")
                if not isinstance(conv_id, str):
                    continue
                try:
                    recipients = await _cached_member_ids(conv_id)
                except Exception:
                    continue  # malformed/unknown conversation id
                if user_id not in recipients:
                    continue  # not a member: drop, don't leak typing signals
                await ws_manager.publish_to_users(
                    org_id,
                    recipients,
                    event,
                    {"conversation_id": conv_id, "user_id": str(user_id)},
                )
    except WebSocketDisconnect:
        pass
    finally:
        await ws_manager.disconnect(org_id, user_id, websocket)
        await redis.setex(presence_key(user_id), PRESENCE_AWAY_TTL_SECONDS, PresenceStatus.AWAY.value)
        await ws_manager.publish_org(
            org_id,
            WsEventServer.PRESENCE_UPDATE,
            {"user_id": str(user_id), "status": PresenceStatus.AWAY.value},
        )
