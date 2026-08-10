"""M4 — message-request tier.

Maps spec §16 acceptance 11–14:
  11) request-tier first message → pending_request conv; second send 403;
      URL in the opening message 403; the recipient push carries no body.
  12) recipient reply AUTO-ACCEPTS atomically (access flips to open in the same
      txn as the reply) → both message freely → exactly one conversation row.
  13) explicit accept flips pending→open with WS + notification to the initiator.
  14) recipient declines → access=declined; the initiator's subsequent send is
      403 request_declined while their conversation still reads pending (no
      leak); the decline is silent; >500 chars rejected; media blocked
      pre-accept; request quota 25/day → 429; a hidden request (new account, no
      shared context) gets no push/badge.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from sqlalchemy import func, select

import app.api.v1.conversations as conversations_module
from app.api.ws_manager import WsManager
from app.core.constants import (
    MESSAGE_REQUEST_QUOTA_PER_DAY,
    PUSH_BODY_MESSAGE_REQUEST,
    PUSH_TITLE,
)
from app.core.enums import ConversationAccess
from app.core.redis_keys import rate_limit_key
from app.db.redis import get_redis
from app.models import Conversation, Notification
from app.services import push_service, spam_heuristics
from app.services.push_service import PushService
from tests import helpers


class FakeSocket:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def send_json(self, payload: dict) -> None:
        self.sent.append(payload)


class RecordingSender:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    async def send(self, *, token, title, body, data, collapse_key) -> bool:
        self.calls.append(
            {"token": token, "title": title, "body": body, "data": data}
        )
        return True


@pytest.fixture
def fake_sender():
    fake = RecordingSender()
    push_service.sender_factory = lambda: fake
    yield fake
    push_service.sender_factory = push_service._default_sender


@pytest.fixture
async def loopback_ws(monkeypatch):
    manager = WsManager()

    async def loopback(user_ids, event, data):
        await manager.deliver_local(
            {"type": event.value, "data": data, "recipients": [str(u) for u in user_ids]}
        )

    monkeypatch.setattr(manager, "publish_to_users", loopback)
    monkeypatch.setattr(conversations_module, "ws_manager", manager)
    return manager


async def _make_pair(db, *, initiator_age_days: int):
    """Two doctors in DIFFERENT orgs, NOT connected → stranger DM resolves to
    the request tier (default dm_policy=connections_and_requests, external
    networking on). Alice initiates; Bob receives."""
    org_a = await helpers.create_org(db, name="Clinic A")
    org_b = await helpers.create_org(db, name="Clinic B")
    alice = await helpers.create_user(db, full_name="Dr Alice")
    bob = await helpers.create_user(db, full_name="Dr Bob")
    await helpers.add_org_member(db, org_a, alice)
    await helpers.add_org_member(db, org_b, bob)
    # Age the initiator so the spam score stays below the hidden threshold
    # unless a test deliberately wants a brand-new account.
    alice.created_at = datetime.now(tz=timezone.utc) - timedelta(days=initiator_age_days)
    await db.commit()
    return SimpleNamespace(
        alice=alice,
        bob=bob,
        alice_headers=await helpers.auth_headers(alice.id),
        bob_headers=await helpers.auth_headers(bob.id),
    )


@pytest.fixture
async def pair(db):
    """Established initiator → a visible (non-hidden) request."""
    return await _make_pair(db, initiator_age_days=30)


async def _create_request(client, pair) -> str:
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(pair.bob.id)]},
        headers=pair.alice_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["access"] == "pending_request"
    assert body["initiator_id"] == str(pair.alice.id)
    assert body["org_id"] is None
    return body["id"]


async def _send(client, headers, conv_id, content, **extra):
    return await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": content, **extra},
        headers=headers,
    )


# --------------------------------------------------------------- test 11


async def test_request_tier_create_and_send_guards(pair, client, db):
    conv_id = await _create_request(client, pair)

    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.access == ConversationAccess.PENDING_REQUEST
    assert conv.last_seq == 0

    # First opening message from the initiator succeeds.
    first = await _send(client, pair.alice_headers, conv_id, "Hi, colleague to consult?")
    assert first.status_code == 200, first.text

    # A second send from the initiator is rejected — one message only.
    second = await _send(client, pair.alice_headers, conv_id, "ping again")
    assert second.status_code == 403
    assert second.json()["detail"] == "request_one_message_only"


async def test_request_opening_message_with_url_rejected(pair, client, db):
    conv_id = await _create_request(client, pair)
    r = await _send(client, pair.alice_headers, conv_id, "reach me at https://spam.example")
    assert r.status_code == 403
    assert r.json()["detail"] == "request_message_invalid"
    # Nothing persisted.
    count = await db.scalar(
        select(func.count()).select_from(Conversation).where(Conversation.id == conv_id)
    )
    assert count == 1
    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.last_seq == 0


async def test_request_opening_message_with_phone_rejected(pair, client):
    conv_id = await _create_request(client, pair)
    r = await _send(client, pair.alice_headers, conv_id, "call me on +1 415 555 0199")
    assert r.status_code == 403
    assert r.json()["detail"] == "request_message_invalid"


async def test_request_over_500_chars_rejected(pair, client):
    conv_id = await _create_request(client, pair)
    r = await _send(client, pair.alice_headers, conv_id, "x" * 501)
    assert r.status_code == 403
    assert r.json()["detail"] == "request_message_invalid"


async def test_message_request_push_carries_no_body(db, fake_sender):
    """The message-request push is generic + PHI-free: fixed copy, no content
    or preview in the payload."""
    bob = await helpers.create_user(db, full_name="Dr Bob")
    token = f"tok-{bob.id}"
    await PushService.register_token(user_id=bob.id, token=token, platform="ios", db=db)
    await db.commit()

    await PushService._dispatch_simple(
        recipient_id=bob.id,
        title=PUSH_TITLE,
        body=PUSH_BODY_MESSAGE_REQUEST,
        data={"type": "message_request", "conversation_id": "abc"},
        collapse_key="request:abc",
    )
    assert fake_sender.calls
    call = fake_sender.calls[0]
    assert call["body"] == "New message request"
    # No message content / preview ever rides along.
    assert "content" not in call["data"]
    assert "preview" not in call["data"]
    assert "body" not in call["data"]


async def test_visible_request_creates_badge_notification(pair, client, db):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")
    # A notification (badge) is created for the recipient.
    notifs = (
        await db.scalars(
            select(Notification).where(Notification.user_id == pair.bob.id)
        )
    ).all()
    assert any(n.type == "message_request_received" for n in notifs)


# --------------------------------------------------------------- test 12


async def test_recipient_reply_auto_accepts_atomically(pair, client, db):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")

    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.access == ConversationAccess.PENDING_REQUEST

    # Bob replies → auto-accept: the SAME send flips access to open.
    reply = await _send(client, pair.bob_headers, conv_id, "Sure, happy to help")
    assert reply.status_code == 200, reply.text
    await db.refresh(conv)
    assert conv.access == ConversationAccess.OPEN

    # Both now message freely.
    assert (await _send(client, pair.alice_headers, conv_id, "great")).status_code == 200
    assert (await _send(client, pair.bob_headers, conv_id, "indeed")).status_code == 200

    # Exactly one conversation row exists for the pair.
    rows = await db.scalar(
        select(func.count())
        .select_from(Conversation)
        .where(Conversation.initiator_id == pair.alice.id)
    )
    assert rows == 1
    # Re-creating from either side returns the same (now open) conversation.
    again = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(pair.bob.id)]},
        headers=pair.alice_headers,
    )
    assert again.status_code == 200
    assert again.json()["id"] == conv_id
    assert again.json()["access"] == "open"


async def test_auto_accept_ws_and_notification_to_initiator(pair, client, db, loopback_ws):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")

    alice_socket = FakeSocket()
    await loopback_ws.connect(pair.alice.id, alice_socket, frozenset())

    reply = await _send(client, pair.bob_headers, conv_id, "Sure")
    assert reply.status_code == 200
    events = [f["type"] for f in alice_socket.sent]
    assert "conversation_request_accepted" in events
    # Initiator gets an acceptance notification (badge).
    notifs = (
        await db.scalars(
            select(Notification).where(Notification.user_id == pair.alice.id)
        )
    ).all()
    assert any(n.type == "message_request_accepted" for n in notifs)


# --------------------------------------------------------------- test 13


async def test_explicit_accept_flips_open_with_ws_and_notification(
    pair, client, db, loopback_ws
):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")

    alice_socket = FakeSocket()
    await loopback_ws.connect(pair.alice.id, alice_socket, frozenset())

    # Initiator cannot accept their own request.
    forbidden = await client.post(
        f"/api/v1/conversations/{conv_id}/request/accept", headers=pair.alice_headers
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"] == "not_the_recipient"

    # Recipient accepts.
    accept = await client.post(
        f"/api/v1/conversations/{conv_id}/request/accept", headers=pair.bob_headers
    )
    assert accept.status_code == 200, accept.text
    assert accept.json()["access"] == "open"

    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.access == ConversationAccess.OPEN

    assert "conversation_request_accepted" in [f["type"] for f in alice_socket.sent]
    notifs = (
        await db.scalars(
            select(Notification).where(Notification.user_id == pair.alice.id)
        )
    ).all()
    assert any(n.type == "message_request_accepted" for n in notifs)

    # Accepting again → 409 (no longer pending).
    again = await client.post(
        f"/api/v1/conversations/{conv_id}/request/accept", headers=pair.bob_headers
    )
    assert again.status_code == 409


# --------------------------------------------------------------- test 14


async def test_decline_is_silent_and_no_leak_to_initiator(pair, client, db, loopback_ws):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")

    # Initiator's socket must NEVER hear about the decline.
    alice_socket = FakeSocket()
    await loopback_ws.connect(pair.alice.id, alice_socket, frozenset())

    decline = await client.post(
        f"/api/v1/conversations/{conv_id}/request/decline", headers=pair.bob_headers
    )
    assert decline.status_code == 200

    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.access == ConversationAccess.DECLINED

    # Silent — no WS to the initiator, and no notification row for them.
    assert alice_socket.sent == []
    initiator_notifs = (
        await db.scalars(
            select(Notification).where(Notification.user_id == pair.alice.id)
        )
    ).all()
    assert initiator_notifs == []

    # Initiator's subsequent send is a plain 403 request_declined.
    send = await _send(client, pair.alice_headers, conv_id, "still there?")
    assert send.status_code == 403
    assert send.json()["detail"] == "request_declined"

    # No leak: the initiator's conversation still READS as pending.
    listing = await client.get("/api/v1/conversations", headers=pair.alice_headers)
    row = next(c for c in listing.json() if c["id"] == conv_id)
    assert row["access"] == "pending_request"


async def test_media_blocked_before_accept(pair, client):
    conv_id = await _create_request(client, pair)
    up = await client.post(
        f"/api/v1/messages/upload/{conv_id}",
        files={"file": ("scan.pdf", b"pdf-bytes", "application/pdf")},
        headers=pair.alice_headers,
    )
    assert up.status_code == 403
    assert up.json()["detail"] == "request_media_blocked"


async def test_request_quota_per_day_429(pair, client, db):
    # Saturate the initiator's daily message-request window.
    redis = await get_redis()
    key = rate_limit_key(pair.alice.id, "message_request_day")
    await redis.set(key, MESSAGE_REQUEST_QUOTA_PER_DAY)

    # A FRESH stranger recipient (new org) keeps this a request-tier create
    # rather than a dedup hit — so it reaches the quota gate.
    org_c = await helpers.create_org(db, name="Clinic C")
    carol = await helpers.create_user(db, full_name="Dr Carol")
    await helpers.add_org_member(db, org_c, carol)

    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(carol.id)]},
        headers=pair.alice_headers,
    )
    assert r.status_code == 429
    assert r.json()["detail"] == "rate_limited"


async def test_new_account_first_request_is_visible(db, client):
    """A doctor who joined yesterday reaching a stranger is the request tier's
    whole purpose — it must reach them with a badge, not be silently hidden.
    Regression: at threshold 2, "new account" + "no shared context" alone buried
    every legitimate first outreach."""
    fresh = await _make_pair(db, initiator_age_days=0)  # brand-new initiator
    conv_id = await _create_request(client, fresh)
    await _send(client, fresh.alice_headers, conv_id, "hello there")

    notifs = (
        await db.scalars(
            select(Notification).where(Notification.user_id == fresh.bob.id)
        )
    ).all()
    assert len(notifs) == 1  # visible → badge

    # And it is listed, unhidden, under the recipient's requests filter.
    listing = await client.get(
        "/api/v1/conversations?filter=requests", headers=fresh.bob_headers
    )
    row = next(c for c in listing.json() if c["id"] == str(conv_id))
    assert row["is_hidden"] is False


def test_spam_score_signals():
    # URL + new account + no shared context → maxed out.
    assert (
        spam_heuristics.request_spam_score(
            content="visit http://x.io",
            sender_account_age_days=1,
            has_shared_context=False,
        )
        == 3
    )
    # Established account with shared context and a clean note → not hidden.
    assert not spam_heuristics.is_hidden_request(
        content="Hi, quick question",
        sender_account_age_days=400,
        has_shared_context=True,
    )
    # Brand-new account with no shared context scores 2 — benign on its own,
    # and NOT enough to hide: that describes every honest first outreach.
    assert (
        spam_heuristics.request_spam_score(
            content="Hi, quick question",
            sender_account_age_days=1,
            has_shared_context=False,
        )
        == 2
    )
    assert not spam_heuristics.is_hidden_request(
        content="Hi, quick question",
        sender_account_age_days=1,
        has_shared_context=False,
    )
    # All three signals together — that is spam.
    assert spam_heuristics.is_hidden_request(
        content="call me on +1 555 0100 999",
        sender_account_age_days=1,
        has_shared_context=False,
    )


async def test_requests_filter_and_default_list_partition(pair, client, db):
    conv_id = await _create_request(client, pair)
    await _send(client, pair.alice_headers, conv_id, "Hello, quick consult?")

    # Recipient: the request appears ONLY under ?filter=requests, not the default.
    default_bob = await client.get("/api/v1/conversations", headers=pair.bob_headers)
    assert all(c["id"] != conv_id for c in default_bob.json())
    requests_bob = await client.get(
        "/api/v1/conversations?filter=requests", headers=pair.bob_headers
    )
    ids = [c["id"] for c in requests_bob.json()]
    assert conv_id in ids
    assert requests_bob.json()[0]["is_hidden"] is False

    # Initiator: the request they SENT shows in their default list (Pending chip).
    default_alice = await client.get("/api/v1/conversations", headers=pair.alice_headers)
    row = next(c for c in default_alice.json() if c["id"] == conv_id)
    assert row["access"] == "pending_request"
    # And NOT in the initiator's Requests tab (those are received-only).
    requests_alice = await client.get(
        "/api/v1/conversations?filter=requests", headers=pair.alice_headers
    )
    assert all(c["id"] != conv_id for c in requests_alice.json())
