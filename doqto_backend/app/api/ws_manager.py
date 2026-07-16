"""In-process WebSocket broadcaster. For multi-replica prod, swap to Redis pub/sub."""

from __future__ import annotations

import asyncio
import uuid
from collections import defaultdict

from fastapi import WebSocket

from app.core.enums import WsEventServer


class WsManager:
    def __init__(self) -> None:
        self._by_org: dict[uuid.UUID, dict[uuid.UUID, set[WebSocket]]] = defaultdict(
            lambda: defaultdict(set)
        )
        self._lock = asyncio.Lock()

    async def connect(self, org_id: uuid.UUID, user_id: uuid.UUID, ws: WebSocket) -> None:
        async with self._lock:
            self._by_org[org_id][user_id].add(ws)

    async def disconnect(self, org_id: uuid.UUID, user_id: uuid.UUID, ws: WebSocket) -> None:
        async with self._lock:
            sockets = self._by_org.get(org_id, {}).get(user_id)
            if sockets is not None:
                sockets.discard(ws)
                if not sockets:
                    self._by_org[org_id].pop(user_id, None)
                if not self._by_org[org_id]:
                    self._by_org.pop(org_id, None)

    async def broadcast_org(self, org_id: uuid.UUID, event: WsEventServer, data: dict) -> None:
        payload = {"type": event.value, "data": data}
        sockets: list[WebSocket] = []
        async with self._lock:
            for user_sockets in self._by_org.get(org_id, {}).values():
                sockets.extend(user_sockets)
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                pass

    async def send_user(
        self, org_id: uuid.UUID, user_id: uuid.UUID, event: WsEventServer, data: dict
    ) -> None:
        payload = {"type": event.value, "data": data}
        sockets: list[WebSocket] = []
        async with self._lock:
            sockets = list(self._by_org.get(org_id, {}).get(user_id, set()))
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                pass


ws_manager = WsManager()
