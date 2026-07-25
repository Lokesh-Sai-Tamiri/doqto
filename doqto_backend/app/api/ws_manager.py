"""WebSocket fanout via Redis pub/sub — user-scoped registry (A1).

Every publish goes through Redis so delivery works across replicas/workers;
each instance's subscriber task delivers to its locally-connected sockets.
Events are recipient-scoped (explicit user-id list) except presence, which is
legitimately org-wide and carries a `{"org_id": ...}` recipients marker.

Envelope shape (new): {"type", "data", "recipients"} where recipients is
either a list of user-id strings OR {"org_id": "..."}.
For one release deliver_local also tolerates the legacy shape
{"org_id", "type", "data", "recipients"} from pre-A1 instances during a
rolling deploy (mirrors the undecryptable-envelope guard).
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
        self._by_user: dict[uuid.UUID, set[WebSocket]] = defaultdict(set)
        # Snapshot of each connected user's active org ids, taken at connect —
        # used only to route org-wide (presence) broadcasts.
        self._orgs_by_user: dict[uuid.UUID, frozenset[uuid.UUID]] = {}
        self._lock = asyncio.Lock()

    async def connect(
        self, user_id: uuid.UUID, ws: WebSocket, org_ids: frozenset[uuid.UUID]
    ) -> None:
        async with self._lock:
            self._by_user[user_id].add(ws)
            self._orgs_by_user[user_id] = org_ids

    async def disconnect(self, user_id: uuid.UUID, ws: WebSocket) -> None:
        async with self._lock:
            sockets = self._by_user.get(user_id)
            if sockets is not None:
                sockets.discard(ws)
                if not sockets:
                    self._by_user.pop(user_id, None)
                    self._orgs_by_user.pop(user_id, None)

    # ---- publishing (any instance) -------------------------------------

    async def publish_to_users(
        self,
        user_ids: list[uuid.UUID],
        event: WsEventServer,
        data: dict,
    ) -> None:
        """Deliver only to the given users — the normal, conversation-scoped path."""
        await self._publish(event, data, recipients=[str(u) for u in user_ids])

    async def publish_org(self, org_id: uuid.UUID, event: WsEventServer, data: dict) -> None:
        """Org-wide delivery — presence only."""
        await self._publish(event, data, recipients={"org_id": str(org_id)})

    async def _publish(
        self,
        event: WsEventServer,
        data: dict,
        *,
        recipients: list[str] | dict,
    ) -> None:
        envelope = {
            "type": event.value,
            "data": data,
            "recipients": recipients,
        }
        redis = await get_redis()
        await redis.publish(WS_EVENTS_CHANNEL, encode_envelope(envelope))

    # ---- delivery (subscriber → local sockets) -------------------------

    async def deliver_local(self, envelope: dict) -> None:
        recipients = envelope.get("recipients")
        payload = {"type": envelope["type"], "data": envelope["data"]}

        # Normalize old + new shapes into (user list | org broadcast).
        org_id: uuid.UUID | None = None
        user_ids: list[uuid.UUID] | None = None
        if isinstance(recipients, dict):  # new org-broadcast marker
            org_id = uuid.UUID(recipients["org_id"])
        elif isinstance(recipients, list):  # user list (new AND legacy shapes)
            user_ids = [uuid.UUID(u) for u in recipients]
        elif recipients is None and "org_id" in envelope:
            # Legacy org broadcast: top-level org_id, recipients=None.
            org_id = uuid.UUID(envelope["org_id"])
        else:
            logger.warning("dropping ws envelope with unrecognized recipients shape")
            return

        sockets: list[WebSocket] = []
        async with self._lock:
            if user_ids is not None:
                for uid in user_ids:
                    sockets.extend(self._by_user.get(uid, set()))
            else:
                for uid, orgs in self._orgs_by_user.items():
                    if org_id in orgs:
                        sockets.extend(self._by_user.get(uid, set()))
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
