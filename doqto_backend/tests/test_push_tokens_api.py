"""POST/DELETE /api/v1/users/me/push-tokens — registration lifecycle."""
from __future__ import annotations

import uuid

from sqlalchemy import select

from app.core.routes import ApiPrefix, ApiRoutes
from app.models import DeviceToken

URL = f"{ApiPrefix.USERS}{ApiRoutes.USERS_PUSH_TOKENS}"


def _token() -> str:
    return f"fake-fcm-token-{uuid.uuid4().hex}"


async def _rows(db) -> list[DeviceToken]:
    # populate_existing: refresh rows the identity map may hold stale copies of
    # (the API wrote them through a different session).
    stmt = select(DeviceToken).execution_options(populate_existing=True)
    return list((await db.scalars(stmt)).all())


async def test_register_requires_auth(client):
    resp = await client.post(URL, json={"token": _token(), "platform": "ios"})
    assert resp.status_code == 401


async def test_register_upsert_is_idempotent(client, db, chat):
    token = _token()
    for _ in range(2):
        resp = await client.post(
            URL, json={"token": token, "platform": "ios"}, headers=chat.alice_headers
        )
        assert resp.status_code == 200
    rows = await _rows(db)
    assert len(rows) == 1
    assert rows[0].user_id == chat.alice.id
    assert rows[0].token == token
    assert rows[0].platform == "ios"


async def test_register_reassigns_token_to_new_user(client, db, chat):
    token = _token()
    resp = await client.post(
        URL, json={"token": token, "platform": "android"}, headers=chat.alice_headers
    )
    assert resp.status_code == 200
    # Same device, bob logs in — token must move to bob, no duplicate row.
    resp = await client.post(
        URL, json={"token": token, "platform": "android"}, headers=chat.bob_headers
    )
    assert resp.status_code == 200
    rows = await _rows(db)
    assert len(rows) == 1
    assert rows[0].user_id == chat.bob.id


async def test_two_tokens_for_one_user(client, db, chat):
    t1, t2 = _token(), _token()
    for t, platform in ((t1, "ios"), (t2, "android")):
        resp = await client.post(
            URL, json={"token": t, "platform": platform}, headers=chat.alice_headers
        )
        assert resp.status_code == 200
    rows = await _rows(db)
    assert {r.token for r in rows} == {t1, t2}
    assert all(r.user_id == chat.alice.id for r in rows)


async def test_delete_removes_only_callers_row(client, db, chat):
    alice_token, bob_token = _token(), _token()
    await client.post(
        URL, json={"token": alice_token, "platform": "ios"}, headers=chat.alice_headers
    )
    await client.post(
        URL, json={"token": bob_token, "platform": "ios"}, headers=chat.bob_headers
    )

    # Bob tries to delete alice's token — scoped delete must be a no-op.
    resp = await client.request(
        "DELETE", URL, json={"token": alice_token}, headers=chat.bob_headers
    )
    assert resp.status_code == 200
    rows = await _rows(db)
    assert {r.token for r in rows} == {alice_token, bob_token}

    # Alice deletes her own token.
    resp = await client.request(
        "DELETE", URL, json={"token": alice_token}, headers=chat.alice_headers
    )
    assert resp.status_code == 200
    rows = await _rows(db)
    assert {r.token for r in rows} == {bob_token}
