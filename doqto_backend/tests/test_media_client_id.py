"""Workstream 3 — client_id idempotency on media + voice-note uploads."""
from __future__ import annotations

import pytest
from sqlalchemy import func, select

from app.models import Message
from app.services.file_service import FileService


@pytest.fixture
def uploads(monkeypatch):
    calls: list[str] = []

    async def fake_upload(*, key, data, content_type):
        calls.append(key)
        return key

    monkeypatch.setattr(FileService, "upload_bytes", fake_upload)
    return calls


async def _upload_file(client, chat, client_id=None):
    data = {} if client_id is None else {"client_id": client_id}
    resp = await client.post(
        f"/api/v1/messages/upload/{chat.conv.id}",
        files={"file": ("scan.pdf", b"pdf-bytes", "application/pdf")},
        data=data,
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


async def _upload_voice(client, chat, client_id=None):
    data = {"duration_sec": "3", "transcript": "hello there"}
    if client_id is not None:
        data["client_id"] = client_id
    resp = await client.post(
        f"/api/v1/messages/voice-notes/{chat.conv.id}",
        files={"file": ("note.m4a", b"audio-bytes", "audio/mp4")},
        data=data,
        headers=chat.alice_headers,
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


async def _count_messages(db, conv_id) -> int:
    return await db.scalar(
        select(func.count()).select_from(Message).where(Message.conversation_id == conv_id)
    )


async def test_file_upload_same_client_id_is_idempotent(client, chat, db, uploads):
    first = await _upload_file(client, chat, client_id="outbox-1")
    second = await _upload_file(client, chat, client_id="outbox-1")

    assert second["id"] == first["id"]
    assert second["seq"] == first["seq"]
    assert second["client_id"] == "outbox-1"
    assert await _count_messages(db, chat.conv.id) == 1
    assert len(uploads) == 1  # retry never re-uploaded to S3


async def test_file_upload_distinct_client_ids_create_two_rows(client, chat, db, uploads):
    first = await _upload_file(client, chat, client_id="outbox-1")
    second = await _upload_file(client, chat, client_id="outbox-2")

    assert second["id"] != first["id"]
    assert await _count_messages(db, chat.conv.id) == 2
    assert len(uploads) == 2


async def test_file_upload_without_client_id_keeps_current_behavior(client, chat, db, uploads):
    first = await _upload_file(client, chat)
    second = await _upload_file(client, chat)

    assert second["id"] != first["id"]
    assert first["client_id"] is None
    assert await _count_messages(db, chat.conv.id) == 2
    assert len(uploads) == 2


async def test_voice_note_same_client_id_is_idempotent(client, chat, db, uploads):
    first = await _upload_voice(client, chat, client_id="voice-1")
    second = await _upload_voice(client, chat, client_id="voice-1")

    assert second["id"] == first["id"]
    assert second["seq"] == first["seq"]
    assert await _count_messages(db, chat.conv.id) == 1
    assert len(uploads) == 1

    third = await _upload_voice(client, chat, client_id="voice-2")
    assert third["id"] != first["id"]
    assert await _count_messages(db, chat.conv.id) == 2
