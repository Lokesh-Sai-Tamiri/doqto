"""Push notification pipeline — presence-gated, sender-side, PHI-free.

Dev default (PUSH_PROVIDER=log) is a logging stub mirroring FakeSNSClient;
real FCM slots in later via PUSH_PROVIDER=fcm + credentials in config.

Payload policy: title/body are the fixed constants PUSH_TITLE /
PUSH_BODY_NEW_MESSAGE — never interpolate user data (HIPAA: pushes transit
Apple/Google unencrypted-to-us). Data carries only the conversation UUID for
deep-linking; collapse key dedupes per conversation.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Protocol

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from app.core.config import settings
from app.core.constants import PUSH_BODY_NEW_MESSAGE, PUSH_TITLE
from app.core.enums import PresenceStatus
from app.core.redis_keys import presence_key
from app.db.postgres import SessionLocal
from app.db.redis import get_redis
from app.models import DeviceToken

log = logging.getLogger("doqto.push")


class PushSender(Protocol):
    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, str], collapse_key: str
    ) -> bool:
        """Deliver one push. Returns False iff the token is permanently
        invalid (unregistered/expired) and its row should be pruned."""
        ...


class DevLogPushSender:
    """Local dev stub — logs instead of sending (mirrors FakeSNSClient)."""

    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, str], collapse_key: str
    ) -> bool:
        log.info("[FAKE PUSH] %s → %s / %s %s", token[:12], title, body, data)
        return True


class FcmPushSender:
    """FCM HTTP v1 sender — skeleton only; wire up when credentials land."""

    def __init__(self) -> None:
        if not settings.FCM_PROJECT_ID or not settings.FCM_SERVICE_ACCOUNT_JSON:
            raise RuntimeError(
                "PUSH_PROVIDER=fcm requires FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_JSON"
            )

    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, str], collapse_key: str
    ) -> bool:
        # TODO(FCM): implement via HTTP v1 —
        #   POST https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send
        #   Authorization: Bearer <OAuth2 token minted from FCM_SERVICE_ACCOUNT_JSON>
        #   {"message": {"token": token,
        #                "notification": {"title": title, "body": body},
        #                "data": data,
        #                "android": {"collapse_key": collapse_key},
        #                "apns": {"headers": {"apns-collapse-id": collapse_key}}}}
        # Return False on 404 / UNREGISTERED (permanently-invalid token),
        # True otherwise.
        raise NotImplementedError("FcmPushSender.send is not wired yet")


def _default_sender() -> PushSender:
    # Mirrors _sns() in auth_service.py — provider keyed on settings.
    if settings.PUSH_PROVIDER == "fcm":
        return FcmPushSender()
    return DevLogPushSender()


# Test seam: tests override this module-level factory to inject a fake sender.
sender_factory = _default_sender


def _sender() -> PushSender:
    return sender_factory()


class PushService:
    @staticmethod
    async def register_token(
        *, user_id: uuid.UUID, token: str, platform: str, db: AsyncSession
    ) -> None:
        """Upsert by token: re-registering reassigns the device to the caller
        (last login wins on a shared device) and bumps last_seen_at."""
        stmt = (
            pg_insert(DeviceToken)
            .values(user_id=user_id, token=token, platform=platform)
            .on_conflict_do_update(
                index_elements=[DeviceToken.token],
                set_={"user_id": user_id, "platform": platform, "last_seen_at": func.now()},
            )
        )
        await db.execute(stmt)
        await db.flush()

    @staticmethod
    async def unregister_token(*, user_id: uuid.UUID, token: str, db: AsyncSession) -> None:
        await db.execute(
            delete(DeviceToken).where(
                DeviceToken.token == token, DeviceToken.user_id == user_id
            )
        )
        await db.flush()

    @staticmethod
    def notify_new_message(
        *,
        conversation_id: uuid.UUID,
        recipient_ids: list[uuid.UUID],
        sender_id: uuid.UUID,
    ) -> None:
        """Fire-and-forget: never blocks or fails the send path."""
        asyncio.create_task(
            PushService._dispatch(
                conversation_id=conversation_id,
                recipient_ids=recipient_ids,
                sender_id=sender_id,
            )
        )

    @staticmethod
    def notify_invitation_received(
        *, recipient_id: uuid.UUID, actor_name: str, invitation_id: uuid.UUID
    ) -> None:
        """Directory data (a doctor's name) is NOT PHI — safe in a push body."""
        asyncio.create_task(
            PushService._dispatch_simple(
                recipient_id=recipient_id,
                title=PUSH_TITLE,
                body=f"{actor_name} wants to connect",
                data={"type": "invitation_received", "invitation_id": str(invitation_id)},
                collapse_key=f"invite:{invitation_id}",
            )
        )

    @staticmethod
    def notify_invitation_accepted(
        *, recipient_id: uuid.UUID, actor_name: str
    ) -> None:
        asyncio.create_task(
            PushService._dispatch_simple(
                recipient_id=recipient_id,
                title=PUSH_TITLE,
                body=f"{actor_name} accepted your connection request",
                data={"type": "invitation_accepted"},
                collapse_key=f"accept:{recipient_id}",
            )
        )

    @staticmethod
    async def _dispatch_simple(
        *,
        recipient_id: uuid.UUID,
        title: str,
        body: str,
        data: dict[str, str],
        collapse_key: str,
    ) -> None:
        """Presence-gated single-recipient push (fire-and-forget)."""
        try:
            redis = await get_redis()
            sender = _sender()
            async with SessionLocal() as db:
                if await redis.get(presence_key(recipient_id)) == PresenceStatus.ONLINE.value:
                    return  # live WS covers them
                rows = (
                    await db.scalars(
                        select(DeviceToken).where(DeviceToken.user_id == recipient_id)
                    )
                ).all()
                for row in rows:
                    ok = await sender.send(
                        token=row.token,
                        title=title,
                        body=body,
                        data=data,
                        collapse_key=collapse_key,
                    )
                    if not ok:
                        await db.delete(row)
                await db.commit()
        except Exception:  # noqa: BLE001 — never propagate into the caller
            log.exception("simple push dispatch failed for user %s", recipient_id)

    @staticmethod
    async def _dispatch(
        *,
        conversation_id: uuid.UUID,
        recipient_ids: list[uuid.UUID],
        sender_id: uuid.UUID,
    ) -> None:
        try:
            redis = await get_redis()
            sender = _sender()
            # PHI-free by policy — constants only, plus the conversation UUID
            # for deep-linking. Nothing else may ever be added here.
            data = {"type": "new_message", "conversation_id": str(conversation_id)}
            # Own session — the request session is closed by the time this runs.
            async with SessionLocal() as db:
                for uid in recipient_ids:
                    if uid == sender_id:
                        continue
                    # ONLINE users have a live WS — local banners cover them.
                    if await redis.get(presence_key(uid)) == PresenceStatus.ONLINE.value:
                        continue
                    rows = (
                        await db.scalars(
                            select(DeviceToken).where(DeviceToken.user_id == uid)
                        )
                    ).all()
                    for row in rows:
                        ok = await sender.send(
                            token=row.token,
                            title=PUSH_TITLE,
                            body=PUSH_BODY_NEW_MESSAGE,
                            data=data,
                            collapse_key=str(conversation_id),
                        )
                        if not ok:
                            await db.delete(row)  # permanently-invalid token
                await db.commit()
        except Exception:  # noqa: BLE001 — never propagate into the send path
            log.exception("push dispatch failed for conversation %s", conversation_id)
