"""M3 — cross-network direct messaging (open tier).

The payoff of the M0 user-scoped socket rewrite: two CONNECTED doctors in
DIFFERENT orgs can DM end-to-end. Maps spec §16 acceptance 6 + 10 + the
headline cross-org delivery regression, network S3 keys, the staged
NETWORK_DM_ENABLED flag, block-freeze, and the A3 group-receipts branch.
"""
from __future__ import annotations

from types import SimpleNamespace

import pytest
from sqlalchemy import func, select

import app.api.v1.conversations as conversations_module
from app.api.ws_manager import WsManager
from app.core.enums import ConversationType
from app.models import (
    Block,
    Conversation,
    ConversationMember,
    DirectConversationKey,
    Message,
    MessageReceipt,
)
from app.services.file_service import FileService
from app.services.message_service import MessageService
from tests import helpers


class FakeSocket:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def send_json(self, payload: dict) -> None:
        self.sent.append(payload)


@pytest.fixture
def uploads(monkeypatch):
    calls: list[str] = []

    async def fake_upload(*, key, data, content_type):
        calls.append(key)
        return key

    monkeypatch.setattr(FileService, "upload_bytes", fake_upload)
    return calls


@pytest.fixture
async def loopback_ws(monkeypatch):
    """Replace the endpoint's ws_manager singleton with a fresh, loop-local
    manager whose publish loops straight back into deliver_local — the httpx
    harness never runs the Redis subscriber, so this simulates it in-process
    to prove user-scoped fanout actually reaches a socket."""
    manager = WsManager()

    async def loopback(user_ids, event, data):
        await manager.deliver_local(
            {"type": event.value, "data": data, "recipients": [str(u) for u in user_ids]}
        )

    monkeypatch.setattr(manager, "publish_to_users", loopback)
    monkeypatch.setattr(conversations_module, "ws_manager", manager)
    return manager


# --------------------------------------------------------------- fixtures


@pytest.fixture
async def same_org(db):
    """Acceptance test 6: two colleagues in ONE org, NOT connected."""
    org = await helpers.create_org(db)
    alice = await helpers.create_user(db, full_name="Dr Alice")
    bob = await helpers.create_user(db, full_name="Dr Bob")
    await helpers.add_org_member(db, org, alice)
    await helpers.add_org_member(db, org, bob)
    return SimpleNamespace(
        org=org,
        alice=alice,
        bob=bob,
        alice_headers=await helpers.auth_headers(alice.id),
        bob_headers=await helpers.auth_headers(bob.id),
    )


@pytest.fixture
async def cross_org(db):
    """Two doctors in DIFFERENT orgs; connected unless a test says otherwise."""
    org_a = await helpers.create_org(db, name="Clinic A")
    org_b = await helpers.create_org(db, name="Clinic B")
    alice = await helpers.create_user(db, full_name="Dr Alice")
    bob = await helpers.create_user(db, full_name="Dr Bob")
    await helpers.add_org_member(db, org_a, alice)
    await helpers.add_org_member(db, org_b, bob)
    return SimpleNamespace(
        org_a=org_a,
        org_b=org_b,
        alice=alice,
        bob=bob,
        alice_headers=await helpers.auth_headers(alice.id),
        bob_headers=await helpers.auth_headers(bob.id),
    )


# ----------------------------------------------- test 6: same-org unchanged


async def test_same_org_colleagues_create_and_message_unchanged(same_org, client, db):
    """Acceptance 6: same-org colleagues (not connected) create a direct
    conversation and message, exactly as before — permission module
    short-circuits shared_org → open."""
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(same_org.bob.id)]},
        headers=same_org.alice_headers,
    )
    assert r.status_code == 200, r.text
    conv_id = r.json()["id"]

    send = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "hello colleague"},
        headers=same_org.alice_headers,
    )
    assert send.status_code == 200, send.text

    # Bob can read it.
    msgs = await client.get(
        f"/api/v1/conversations/{conv_id}/messages", headers=same_org.bob_headers
    )
    assert msgs.status_code == 200
    assert [m["content"] for m in msgs.json()] == ["hello colleague"]


# --------------------------------------------- headline cross-org delivery


async def test_connected_cross_org_dm_delivers_over_user_socket(
    cross_org, client, db, loopback_ws
):
    """THE regression: two connected doctors in different orgs create a direct
    conversation (org_id NULL), send a message, and the recipient RECEIVES it
    over the user-scoped socket — impossible pre-M0 (org-partitioned bus)."""
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)

    # Bob's live socket registered on the (loop-local) user-scoped registry.
    bob_socket = FakeSocket()
    await loopback_ws.connect(cross_org.bob.id, bob_socket, frozenset())

    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    conv_id = body["id"]
    assert body["org_id"] is None
    assert body["is_network"] is True
    assert body["access"] == "open"

    conv = await db.scalar(select(Conversation).where(Conversation.id == conv_id))
    assert conv.org_id is None

    send = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "cross-org hello"},
        headers=cross_org.alice_headers,
    )
    assert send.status_code == 200, send.text

    # Delivered to Bob's socket across the org boundary.
    assert bob_socket.sent, "recipient socket received nothing"
    frame = bob_socket.sent[-1]
    assert frame["type"] == "new_message"
    assert frame["data"]["content"] == "cross-org hello"


async def test_network_file_upload_lands_under_network_prefix(
    cross_org, client, db, uploads
):
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    conv_id = r.json()["id"]

    up = await client.post(
        f"/api/v1/messages/upload/{conv_id}",
        files={"file": ("scan.pdf", b"pdf-bytes", "application/pdf")},
        headers=cross_org.alice_headers,
    )
    assert up.status_code == 200, up.text
    assert len(uploads) == 1
    assert uploads[0].startswith(f"files/network/{conv_id}/")
    assert "scan.pdf" in uploads[0]


# ---------------------------------------------- test 10: idempotent send


async def test_idempotent_client_message_id_one_row_same_seq(cross_org, client, db):
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    conv_id = r.json()["id"]

    first = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "retry me", "client_id": "outbox-42"},
        headers=cross_org.alice_headers,
    )
    second = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "retry me", "client_id": "outbox-42"},
        headers=cross_org.alice_headers,
    )
    assert first.status_code == second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    assert first.json()["seq"] == second.json()["seq"]

    count = await db.scalar(
        select(func.count()).select_from(Message).where(Message.conversation_id == conv_id)
    )
    assert count == 1


# --------------------------------------------- disconnected + denied paths


async def test_disconnected_cross_org_pair_is_denied(cross_org, client):
    """No shared org, not connected → 403 not_connected. There is no
    message-request tier: connect first, then chat."""
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    assert r.status_code == 403, r.text
    assert r.json()["detail"] == "not_connected"


async def test_block_freezes_sends_both_ways(cross_org, client, db):
    """A block mid-conversation freezes the network DM for both directions."""
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    conv_id = r.json()["id"]
    # Both can send before the block.
    assert (
        await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"content": "before"},
            headers=cross_org.alice_headers,
        )
    ).status_code == 200

    db.add(Block(blocker_id=cross_org.alice.id, blocked_id=cross_org.bob.id))
    await db.commit()

    # Blocker cannot send.
    a = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "after (alice)"},
        headers=cross_org.alice_headers,
    )
    assert a.status_code == 403
    # Blocked user cannot send either.
    b = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "after (bob)"},
        headers=cross_org.bob_headers,
    )
    assert b.status_code == 403


# --------------------------------------------- NETWORK_DM_ENABLED flag


async def test_flag_off_blocks_cross_org_but_not_same_org(
    cross_org, same_org, client, db, monkeypatch
):
    from app.core.config import settings

    monkeypatch.setattr(settings, "NETWORK_DM_ENABLED", False)

    # Cross-org connected pair is blocked at creation.
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)
    blocked = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "network_dm_disabled"

    # Same-org creation is never gated by the flag.
    ok = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(same_org.bob.id)]},
        headers=same_org.alice_headers,
    )
    assert ok.status_code == 200, ok.text


# --------------------------------------------- A3 group-receipts branch


@pytest.fixture
async def group_chat(db):
    org = await helpers.create_org(db)
    alice = await helpers.create_user(db, full_name="Dr Alice")
    bob = await helpers.create_user(db, full_name="Dr Bob")
    carol = await helpers.create_user(db, full_name="Dr Carol")
    for u in (alice, bob, carol):
        await helpers.add_org_member(db, org, u)
    conv = await helpers.create_conversation(
        db, org, [alice, bob, carol], conv_type=ConversationType.GROUP, name="Team"
    )
    return SimpleNamespace(
        org=org,
        conv=conv,
        alice=alice,
        bob=bob,
        carol=carol,
        alice_headers=await helpers.auth_headers(alice.id),
        bob_headers=await helpers.auth_headers(bob.id),
        carol_headers=await helpers.auth_headers(carol.id),
    )


async def _unread_for(client, headers, conv_id) -> int:
    resp = await client.get("/api/v1/conversations", headers=headers)
    assert resp.status_code == 200
    row = next(c for c in resp.json() if c["id"] == str(conv_id))
    return row["unread_count"]


async def test_group_receipts_use_last_read_seq(group_chat, client, db):
    conv_id = str(group_chat.conv.id)
    # Alice sends two messages.
    for text in ("m1", "m2"):
        s = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"content": text},
            headers=group_chat.alice_headers,
        )
        assert s.status_code == 200, s.text

    # Bob sees 2 unread (seq-cursor based, not receipts).
    assert await _unread_for(client, group_chat.bob_headers, conv_id) == 2

    # Bob reads → cursor advances, no MessageReceipt rows written for the group.
    read = await client.post(
        f"/api/v1/conversations/{conv_id}/read", headers=group_chat.bob_headers
    )
    assert read.status_code == 200
    assert await _unread_for(client, group_chat.bob_headers, conv_id) == 0

    bob_member = await db.scalar(
        select(ConversationMember).where(
            ConversationMember.conversation_id == group_chat.conv.id,
            ConversationMember.user_id == group_chat.bob.id,
        )
    )
    await db.refresh(bob_member)
    assert bob_member.last_read_seq == 2

    receipts = await db.scalar(
        select(func.count())
        .select_from(MessageReceipt)
        .join(Message, Message.id == MessageReceipt.message_id)
        .where(Message.conversation_id == group_chat.conv.id)
    )
    assert receipts == 0  # group path never writes per-message receipts

    # Read-by: alice's messages show read only once ALL other members have read.
    # Only Bob has read so far → not fully read.
    alice_view = await client.get(
        f"/api/v1/conversations/{conv_id}/messages", headers=group_chat.alice_headers
    )
    assert all(m["read"] is False for m in alice_view.json())

    # Carol reads too → now fully read-by.
    await client.post(
        f"/api/v1/conversations/{conv_id}/read", headers=group_chat.carol_headers
    )
    alice_view2 = await client.get(
        f"/api/v1/conversations/{conv_id}/messages", headers=group_chat.alice_headers
    )
    assert all(m["read"] is True for m in alice_view2.json())


async def test_direct_conversation_still_uses_receipts(cross_org, client, db):
    """Regression guard: DIRECT conversations keep per-message MessageReceipt
    rows while groups use the seq cursor."""
    await helpers.connect_users(db, cross_org.alice, cross_org.bob)
    r = await client.post(
        "/api/v1/conversations",
        json={"type": "direct", "member_ids": [str(cross_org.bob.id)]},
        headers=cross_org.alice_headers,
    )
    conv_id = r.json()["id"]
    await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "hi"},
        headers=cross_org.alice_headers,
    )
    await client.post(
        f"/api/v1/conversations/{conv_id}/read", headers=cross_org.bob_headers
    )
    receipts = await db.scalar(
        select(func.count())
        .select_from(MessageReceipt)
        .join(Message, Message.id == MessageReceipt.message_id)
        .where(Message.conversation_id == conv_id)
    )
    assert receipts >= 1  # direct still writes receipts


async def test_legacy_requests_filter_is_empty(same_org, client):
    """Old clients ask for ?filter=requests; with no request tier that must be
    an empty list, never the whole inbox."""
    r = await client.get("/api/v1/conversations", params={"filter": "requests"}, headers=same_org.alice_headers)
    assert r.status_code == 200 and r.json() == []
    r = await client.get("/api/v1/conversations", headers=same_org.alice_headers)
    assert r.status_code == 200
