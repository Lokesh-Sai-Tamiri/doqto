"""WebSocket fanout via Redis pub/sub.

Every publish goes through Redis so delivery works across replicas/workers;
each instance's subscriber task delivers to its locally-connected sockets.
Events are conversation-scoped (explicit recipient list) except presence,
which is legitimately org-wide.
"""

from __future__ import annotations

import asyncio
import base64
import json
import logging
import uuid
from collections import defaultdict

from fastapi import WebSocket

from app.core.enums import WsEventServer
from app.core.redis_keys import WS_EVENTS_CHANNEL
from app.core.security import decrypt_message, encrypt_message
from app.db.redis import get_redis

logger = logging.getLogger(__name__)


def encode_envelope(envelope: dict) -> str:
    """AES-GCM-encrypt the envelope so decrypted PHI never transits Redis in
    cleartext. Base64 keeps it a str (redis client uses decode_responses)."""
    return base64.b64encode(encrypt_message(json.dumps(envelope))).decode()


def decode_envelope(data: str) -> dict:
    return json.loads(decrypt_message(base64.b64decode(data)))


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

    # ---- publishing (any instance) -------------------------------------

    async def publish_to_users(
        self,
        org_id: uuid.UUID,
        user_ids: list[uuid.UUID],
        event: WsEventServer,
        data: dict,
    ) -> None:
        """Deliver only to the given users — the normal, conversation-scoped path."""
        await self._publish(org_id, event, data, recipients=[str(u) for u in user_ids])

    async def publish_org(self, org_id: uuid.UUID, event: WsEventServer, data: dict) -> None:
        """Org-wide delivery — presence only."""
        await self._publish(org_id, event, data, recipients=None)

    async def _publish(
        self,
        org_id: uuid.UUID,
        event: WsEventServer,
        data: dict,
        *,
        recipients: list[str] | None,
    ) -> None:
        envelope = {
            "org_id": str(org_id),
            "type": event.value,
            "data": data,
            "recipients": recipients,
        }
        redis = await get_redis()
        await redis.publish(WS_EVENTS_CHANNEL, encode_envelope(envelope))

    # ---- delivery (subscriber → local sockets) -------------------------

    async def deliver_local(self, envelope: dict) -> None:
        org_id = uuid.UUID(envelope["org_id"])
        recipients: list[str] | None = envelope.get("recipients")
        payload = {"type": envelope["type"], "data": envelope["data"]}

        sockets: list[WebSocket] = []
        async with self._lock:
            users = self._by_org.get(org_id, {})
            if recipients is None:
                for user_sockets in users.values():
                    sockets.extend(user_sockets)
            else:
                for uid in recipients:
                    sockets.extend(users.get(uuid.UUID(uid), set()))
        for ws in sockets:
            try:
                await ws.send_json(payload)
            except Exception:
                pass  # dead socket; its disconnect handler cleans up

    async def run_subscriber(self) -> None:
        """Lifespan task: pump Redis pub/sub into local sockets. Reconnects on error."""
        while True:
            try:
                redis = await get_redis()
                pubsub = redis.pubsub()
                await pubsub.subscribe(WS_EVENTS_CHANNEL)
                async for message in pubsub.listen():
                    if message.get("type") != "message":
                        continue
                    try:
                        envelope = decode_envelope(message["data"])
                    except Exception:
                        # Undecryptable (e.g. plaintext from a pre-encryption
                        # instance during a rolling deploy) — drop, don't crash.
                        logger.warning("dropping undecryptable ws envelope")
                        continue
                    try:
                        await self.deliver_local(envelope)
                    except Exception:
                        logger.exception("ws envelope delivery failed")
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("ws subscriber lost Redis; retrying in 1s")
                await asyncio.sleep(1)


ws_manager = WsManager()
