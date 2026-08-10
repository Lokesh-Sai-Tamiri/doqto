"""Harness smoke tests — DB, Redis, auth, and the ASGI app all wired up."""
from __future__ import annotations


async def test_health(client):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


async def test_authed_conversation_list(client, chat):
    resp = await client.get("/api/v1/conversations", headers=chat.alice_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["id"] == str(chat.conv.id)


async def test_unauthed_request_rejected(client):
    resp = await client.get("/api/v1/conversations")
    assert resp.status_code == 401
