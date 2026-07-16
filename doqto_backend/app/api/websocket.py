from __future__ import annotations

import uuid

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from redis.asyncio import Redis
from sqlalchemy import select

from app.api.ws_manager import ws_manager
from app.core.constants import PRESENCE_AWAY_TTL_SECONDS, PRESENCE_ONLINE_TTL_SECONDS
from app.core.enums import JwtTokenType, PresenceStatus, WsEventClient, WsEventServer
from app.core.redis_keys import presence_key
from app.core.security import TokenError, decode_token
from app.db.postgres import SessionLocal
from app.db.redis import get_redis
from app.models import OrgMember

router = APIRouter()


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
async def websocket_endpoint(
    websocket: WebSocket,
    org_id: uuid.UUID,
    token: str = Query(...),
) -> None:
    try:
        user_id = await _authorize(token, org_id)
    except TokenError:
        await websocket.close(code=4401)
        return

    await websocket.accept()
    await ws_manager.connect(org_id, user_id, websocket)
    redis: Redis = await get_redis()
    await redis.setex(presence_key(user_id), PRESENCE_ONLINE_TTL_SECONDS, PresenceStatus.ONLINE.value)
    await ws_manager.broadcast_org(
        org_id,
        WsEventServer.PRESENCE_UPDATE,
        {"user_id": str(user_id), "status": PresenceStatus.ONLINE.value},
    )

    try:
        while True:
            msg = await websocket.receive_json()
            msg_type = msg.get("type")
            if msg_type == WsEventClient.HEARTBEAT.value:
                await redis.setex(
                    presence_key(user_id), PRESENCE_ONLINE_TTL_SECONDS, PresenceStatus.ONLINE.value
                )
            elif msg_type in (WsEventClient.TYPING_START.value, WsEventClient.TYPING_STOP.value):
                event = (
                    WsEventServer.TYPING_START
                    if msg_type == WsEventClient.TYPING_START.value
                    else WsEventServer.TYPING_STOP
                )
                await ws_manager.broadcast_org(
                    org_id,
                    event,
                    {"conversation_id": msg.get("conversation_id"), "user_id": str(user_id)},
                )
    except WebSocketDisconnect:
        pass
    finally:
        await ws_manager.disconnect(org_id, user_id, websocket)
        await redis.setex(presence_key(user_id), PRESENCE_AWAY_TTL_SECONDS, PresenceStatus.AWAY.value)
        await ws_manager.broadcast_org(
            org_id,
            WsEventServer.PRESENCE_UPDATE,
            {"user_id": str(user_id), "status": PresenceStatus.AWAY.value},
        )
