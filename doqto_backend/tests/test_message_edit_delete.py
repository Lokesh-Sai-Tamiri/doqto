"""Message edit (5 min, transparent history) and delete (3 min, tombstone)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select, update

from app.api.ws_manager import ws_manager
from app.core.constants import MESSAGE_DELETE_WINDOW_SEC, MESSAGE_EDIT_WINDOW_SEC
from app.models import Message, MessageEdit
from app.services.file_service import FileService


async def _send(client, chat, content="hello", headers=None):
    resp = await client.post(
        f"/api/v1/conversations/{chat.conv.id}/messages",
        json={"type": "text", "content": content},
        headers=headers or chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


async def _backdate(db, message_id: str, seconds: int) -> None:
    await db.execute(
        update(Message)
        .where(Message.id == message_id)
        .values(created_at=datetime.now(tz=timezone.utc) - timedelta(seconds=seconds))
    )
    await db.commit()


@pytest.fixture
def ws_events(monkeypatch):
    events: list[tuple[str, dict]] = []

    async def fake_publish(user_ids, event, data):
        events.append((str(event), data))

    monkeypatch.setattr(ws_manager, "publish_to_users", fake_publish)
    return events


async def test_edit_replaces_content_and_keeps_history(client, chat, db, ws_events):
    msg = await _send(client, chat, "first draft")
    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}",
        json={"content": "second draft"},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    out = resp.json()
    assert out["content"] == "second draft"
    assert out["edited_at"] is not None
    assert out["seq"] == msg["seq"]

    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}",
        json={"content": "third draft"},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200

    # History visible to the OTHER member, oldest first.
    resp = await client.get(f"/api/v1/messages/{msg['id']}/edits", headers=chat.bob_headers)
    assert resp.status_code == 200
    assert [e["content"] for e in resp.json()] == ["first draft", "second draft"]

    edited = [d for ev, d in ws_events if ev == "message_edited"]
    assert len(edited) == 2 and edited[-1]["content"] == "third draft"

    # The thread lists the current content.
    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages", headers=chat.bob_headers
    )
    assert resp.json()[0]["content"] == "third draft"


async def test_edit_same_content_is_noop(client, chat, db):
    msg = await _send(client, chat, "same")
    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}", json={"content": "same"}, headers=chat.alice_headers
    )
    assert resp.status_code == 200
    assert resp.json()["edited_at"] is None
    resp = await client.get(f"/api/v1/messages/{msg['id']}/edits", headers=chat.alice_headers)
    assert resp.json() == []


async def test_edit_after_window_is_409(client, chat, db):
    msg = await _send(client, chat)
    await _backdate(db, msg["id"], MESSAGE_EDIT_WINDOW_SEC + 1)
    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}", json={"content": "late"}, headers=chat.alice_headers
    )
    assert resp.status_code == 409
    assert resp.json()["detail"] == "edit_window_closed"


async def test_edit_by_non_sender_is_403(client, chat, db):
    msg = await _send(client, chat)
    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}", json={"content": "nope"}, headers=chat.bob_headers
    )
    assert resp.status_code == 403
    assert resp.json()["detail"] == "not_message_sender"


async def test_edit_non_text_is_409(client, chat, db, monkeypatch):
    async def fake_upload(*, key, data, content_type):
        return key

    monkeypatch.setattr(FileService, "upload_bytes", fake_upload)
    resp = await client.post(
        f"/api/v1/messages/upload/{chat.conv.id}",
        files={"file": ("scan.pdf", b"pdf", "application/pdf")},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    resp = await client.patch(
        f"/api/v1/messages/{resp.json()['id']}",
        json={"content": "x"},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 409
    assert resp.json()["detail"] == "message_not_editable"


async def test_delete_tombstones_and_shreds(client, chat, db, ws_events):
    msg = await _send(client, chat, "secret")
    await client.patch(
        f"/api/v1/messages/{msg['id']}", json={"content": "secret v2"}, headers=chat.alice_headers
    )
    resp = await client.delete(f"/api/v1/messages/{msg['id']}", headers=chat.alice_headers)
    assert resp.status_code == 200, resp.text
    out = resp.json()
    assert out["deleted_at"] is not None
    assert out["content"] is None
    assert out["seq"] == msg["seq"]

    row = await db.scalar(select(Message).where(Message.id == msg["id"]))
    assert row.content_encrypted is None and row.deleted_at is not None
    assert row.is_deleted is False  # still listed — it's a tombstone, not a purge
    edits = (await db.execute(select(MessageEdit).where(MessageEdit.message_id == row.id))).all()
    assert edits == []

    deleted = [d for ev, d in ws_events if ev == "message_deleted"]
    assert len(deleted) == 1 and deleted[0]["id"] == msg["id"]

    # Both sides still see the row (as a tombstone) and history is empty.
    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages", headers=chat.bob_headers
    )
    listed = resp.json()
    assert listed[0]["id"] == msg["id"] and listed[0]["deleted_at"] is not None
    resp = await client.get(f"/api/v1/messages/{msg['id']}/edits", headers=chat.bob_headers)
    assert resp.json() == []

    # Chat-list preview is the tombstone text, never the old content.
    resp = await client.get("/api/v1/conversations", headers=chat.bob_headers)
    conv = next(c for c in resp.json() if c["id"] == str(chat.conv.id))
    assert conv["last_message_preview"] == "This message was deleted"


async def test_delete_media_removes_s3_object(client, chat, db, monkeypatch):
    deleted_keys: list[str] = []

    async def fake_upload(*, key, data, content_type):
        return key

    async def fake_delete(*, key):
        deleted_keys.append(key)

    monkeypatch.setattr(FileService, "upload_bytes", fake_upload)
    monkeypatch.setattr(FileService, "delete_object", fake_delete)
    resp = await client.post(
        f"/api/v1/messages/upload/{chat.conv.id}",
        files={"file": ("scan.pdf", b"pdf", "application/pdf")},
        headers=chat.alice_headers,
    )
    key = resp.json()["s3_key"]
    resp = await client.delete(f"/api/v1/messages/{resp.json()['id']}", headers=chat.alice_headers)
    assert resp.status_code == 200, resp.text
    assert resp.json()["s3_key"] is None
    assert deleted_keys == [key]


async def test_delete_after_window_is_409(client, chat, db):
    msg = await _send(client, chat)
    await _backdate(db, msg["id"], MESSAGE_DELETE_WINDOW_SEC + 1)
    resp = await client.delete(f"/api/v1/messages/{msg['id']}", headers=chat.alice_headers)
    assert resp.status_code == 409
    assert resp.json()["detail"] == "delete_window_closed"


async def test_delete_by_non_sender_is_403(client, chat, db):
    msg = await _send(client, chat)
    resp = await client.delete(f"/api/v1/messages/{msg['id']}", headers=chat.bob_headers)
    assert resp.status_code == 403


async def test_edit_or_delete_after_delete_is_409(client, chat, db):
    msg = await _send(client, chat)
    assert (
        await client.delete(f"/api/v1/messages/{msg['id']}", headers=chat.alice_headers)
    ).status_code == 200
    resp = await client.patch(
        f"/api/v1/messages/{msg['id']}", json={"content": "x"}, headers=chat.alice_headers
    )
    assert resp.status_code == 409 and resp.json()["detail"] == "message_deleted"
    resp = await client.delete(f"/api/v1/messages/{msg['id']}", headers=chat.alice_headers)
    assert resp.status_code == 409 and resp.json()["detail"] == "message_deleted"


async def test_history_requires_membership(client, chat, db):
    from tests import helpers

    msg = await _send(client, chat)
    outsider = await helpers.create_user(db, full_name="Dr Outsider")
    resp = await client.get(
        f"/api/v1/messages/{msg['id']}/edits",
        headers=await helpers.auth_headers(outsider.id),
    )
    assert resp.status_code == 403


async def test_hide_is_per_user_any_message_any_age(client, chat, db):
    """'Delete for me': mine or theirs, old or tombstone; the other side keeps it."""
    mine = await _send(client, chat, "mine")
    theirs = await _send(client, chat, "theirs", headers=chat.bob_headers)
    await _backdate(db, theirs["id"], MESSAGE_DELETE_WINDOW_SEC * 10)
    resp = await client.post(
        "/api/v1/messages/hide",
        json={"message_ids": [mine["id"], theirs["id"]]},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text

    ids = lambda r: [m["id"] for m in r.json()]  # noqa: E731
    url = f"/api/v1/conversations/{chat.conv.id}/messages"
    alice = ids(await client.get(url, headers=chat.alice_headers))
    assert mine["id"] not in alice and theirs["id"] not in alice
    bob = ids(await client.get(url, headers=chat.bob_headers))
    assert mine["id"] in bob and theirs["id"] in bob

    # Chat-list preview skips what I hid.
    resp = await client.get("/api/v1/conversations", headers=chat.alice_headers)
    conv = next(c for c in resp.json() if c["id"] == str(chat.conv.id))
    assert conv["last_message_preview"] != "theirs"
    # Idempotent.
    resp = await client.post(
        "/api/v1/messages/hide", json={"message_ids": [mine["id"]]}, headers=chat.alice_headers
    )
    assert resp.status_code == 200


async def test_hide_ignores_messages_outside_my_conversations(client, chat, db):
    from tests import helpers

    msg = await _send(client, chat)
    outsider = await helpers.create_user(db, full_name="Dr Outsider")
    resp = await client.post(
        "/api/v1/messages/hide",
        json={"message_ids": [msg["id"]]},
        headers=await helpers.auth_headers(outsider.id),
    )
    assert resp.status_code == 200
    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages", headers=chat.alice_headers
    )
    assert msg["id"] in [m["id"] for m in resp.json()]
