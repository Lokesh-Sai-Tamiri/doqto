"""PushService._dispatch — presence gating, sender exclusion, token pruning,
and the PHI guard (payload must be constants + conversation UUID, nothing else).

_dispatch is awaited directly (not via notify_new_message's create_task) so
tests don't depend on task scheduling."""
from __future__ import annotations

import uuid

import pytest
from sqlalchemy import func, select

from app.core.constants import (
    PRESENCE_AWAY_TTL_SECONDS,
    PRESENCE_ONLINE_TTL_SECONDS,
    PUSH_BODY_NEW_MESSAGE,
    PUSH_TITLE,
)
from app.core.enums import PresenceStatus
from app.core.redis_keys import presence_key
from app.db.redis import get_redis
from app.models import DeviceToken
from app.services import push_service
from app.services.push_service import PushService


class RecordingSender:
    """Records every send; returns False for tokens in invalid_tokens."""

    def __init__(self) -> None:
        self.calls: list[dict] = []
        self.invalid_tokens: set[str] = set()

    async def send(
        self, *, token: str, title: str, body: str, data: dict[str, str], collapse_key: str
    ) -> bool:
        self.calls.append(
            {
                "token": token,
                "title": title,
                "body": body,
                "data": data,
                "collapse_key": collapse_key,
            }
        )
        return token not in self.invalid_tokens


@pytest.fixture
def fake_sender():
    fake = RecordingSender()
    push_service.sender_factory = lambda: fake
    yield fake
    push_service.sender_factory = push_service._default_sender


async def _register(db, user_id: uuid.UUID) -> str:
    token = f"fake-token-{uuid.uuid4().hex}"
    await PushService.register_token(
        user_id=user_id, token=token, platform="ios", db=db
    )
    await db.commit()
    return token


async def _set_presence(user_id: uuid.UUID, status: PresenceStatus, ttl: int) -> None:
    redis = await get_redis()
    await redis.setex(presence_key(user_id), ttl, status.value)


async def _dispatch(chat) -> None:
    await PushService._dispatch(
        conversation_id=chat.conv.id,
        recipient_ids=[chat.alice.id, chat.bob.id],
        sender_id=chat.alice.id,
    )


async def test_online_recipient_is_still_pushed(db, chat, fake_sender):
    """A killed iOS app keeps its socket 'online' for minutes; FCM suppresses
    foreground display itself, so presence must not gate the push."""
    token = await _register(db, chat.bob.id)
    await _set_presence(chat.bob.id, PresenceStatus.ONLINE, PRESENCE_ONLINE_TTL_SECONDS)
    await _dispatch(chat)
    assert [c["token"] for c in fake_sender.calls] == [token]


async def test_away_recipient_is_pushed(db, chat, fake_sender):
    token = await _register(db, chat.bob.id)
    await _set_presence(chat.bob.id, PresenceStatus.AWAY, PRESENCE_AWAY_TTL_SECONDS)
    await _dispatch(chat)
    assert [c["token"] for c in fake_sender.calls] == [token]


async def test_absent_presence_is_pushed(db, chat, fake_sender):
    token = await _register(db, chat.bob.id)  # no presence key at all
    await _dispatch(chat)
    assert [c["token"] for c in fake_sender.calls] == [token]


async def test_sender_is_excluded(db, chat, fake_sender):
    await _register(db, chat.alice.id)  # sender's own device, offline
    bob_token = await _register(db, chat.bob.id)
    await _dispatch(chat)
    assert [c["token"] for c in fake_sender.calls] == [bob_token]


async def test_invalid_token_row_is_pruned(db, chat, fake_sender):
    token = await _register(db, chat.bob.id)
    fake_sender.invalid_tokens.add(token)
    await _dispatch(chat)
    assert [c["token"] for c in fake_sender.calls] == [token]
    db.expire_all()
    count = await db.scalar(select(func.count()).select_from(DeviceToken))
    assert count == 0


async def test_payload_is_phi_free(db, chat, fake_sender):
    """The payload must be EXACTLY the constants + conversation UUID —
    never message content, sender name, or any other user data."""
    await _register(db, chat.bob.id)
    await _dispatch(chat)
    assert len(fake_sender.calls) == 1
    call = fake_sender.calls[0]
    assert call["title"] == PUSH_TITLE
    assert call["body"] == PUSH_BODY_NEW_MESSAGE
    assert set(call["data"].keys()) == {"type", "conversation_id"}
    assert call["data"]["type"] == "new_message"
    assert call["data"]["conversation_id"] == str(chat.conv.id)
    assert call["collapse_key"] == str(chat.conv.id)
