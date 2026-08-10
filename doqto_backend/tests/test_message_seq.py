"""Workstream 1 — per-conversation sequence numbers + since-sync."""
from __future__ import annotations

import asyncio

import pytest
from sqlalchemy import select

from app.db.postgres import SessionLocal
from app.models import Conversation, Message
from app.services.file_service import FileService
from app.services.message_service import MessageService


@pytest.fixture
def _fake_s3(monkeypatch):
    uploads: list[str] = []

    async def fake_upload(*, key, data, content_type):
        uploads.append(key)
        return key

    monkeypatch.setattr(FileService, "upload_bytes", fake_upload)
    return uploads


async def _send_text(client, chat, content, **extra):
    resp = await client.post(
        f"/api/v1/conversations/{chat.conv.id}/messages",
        json={"type": "text", "content": content, **extra},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


async def test_seq_sequential_across_text_system_upload(client, chat, db, _fake_s3):
    m1 = await _send_text(client, chat, "first")
    assert m1["seq"] == 1

    m2 = await _send_text(client, chat, "second")
    assert m2["seq"] == 2

    # System message via the service path.
    conv = await db.scalar(select(Conversation).where(Conversation.id == chat.conv.id))
    sys_msg = await MessageService.send_system(
        conv=conv, sender_id=chat.alice.id, content="timer changed", db=db
    )
    await db.commit()
    assert sys_msg.seq == 3

    # Upload path.
    resp = await client.post(
        f"/api/v1/messages/upload/{chat.conv.id}",
        files={"file": ("scan.pdf", b"pdf-bytes", "application/pdf")},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["seq"] == 4

    # conversations.last_seq tracks the highest handed-out seq.
    await db.refresh(conv)
    assert conv.last_seq == 4


async def test_concurrent_sends_get_unique_seqs(chat):
    async def send(i: int) -> int:
        async with SessionLocal() as db:
            msg = await MessageService.send_text(
                conversation_id=chat.conv.id,
                sender_id=chat.alice.id,
                content=f"msg {i}",
                db=db,
            )
            await db.commit()
            return msg.seq

    seqs = await asyncio.gather(*(send(i) for i in range(8)))
    assert sorted(seqs) == list(range(1, 9))


async def test_after_seq_filters_and_orders_ascending(client, chat):
    for i in range(5):
        await _send_text(client, chat, f"msg {i}")

    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages",
        params={"after_seq": 2},
        headers=chat.bob_headers,
    )
    assert resp.status_code == 200
    seqs = [m["seq"] for m in resp.json()]
    assert seqs == [3, 4, 5]

    # after_seq=0 → full history, oldest first.
    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages",
        params={"after_seq": 0},
        headers=chat.bob_headers,
    )
    assert [m["seq"] for m in resp.json()] == [1, 2, 3, 4, 5]


async def test_before_and_after_seq_together_is_400(client, chat):
    resp = await client.get(
        f"/api/v1/conversations/{chat.conv.id}/messages",
        params={"after_seq": 1, "before": "2026-01-01T00:00:00Z"},
        headers=chat.alice_headers,
    )
    assert resp.status_code == 400
    assert resp.json()["detail"] == "before_and_after_seq_exclusive"


async def test_to_out_and_ws_payload_include_seq(chat, db):
    msg = await MessageService.send_text(
        conversation_id=chat.conv.id,
        sender_id=chat.alice.id,
        content="hello",
        db=db,
    )
    await db.commit()
    out = MessageService.to_out(msg)
    assert out.seq == 1
    # WS NEW_MESSAGE payload is model_dump of MessageOut — seq rides along.
    assert out.model_dump(mode="json")["seq"] == 1

    row = await db.scalar(select(Message).where(Message.id == msg.id))
    assert row.seq == 1
