"""M5 — groups.

Maps spec §16 acceptance 15–20 (+ the group angles of 13/20):
  15) join request → approve → membership + system message + notification;
      reject → 14-day re-request cooldown.
  16) secret group → 404 to non-members on GET + absent from discovery;
      revoked link-invite token → 404.
  17) NO endpoint adds a user to a group without consent — join/invite/approve
      probed; bulk-add is impossible (an invite only creates membership once the
      invitee accepts).
  18) owner cannot leave without transferring ownership (409).
  13) two group members who are NOT connected can both post in the group chat
      (membership == permission).
  member_dm_policy matrix (open→direct, request→request tier, disabled→denied).
  20) last_read_seq unread / read-by correctness at a group with many members
      (reuse A3 branch).
  legacy type=group org chats are unaffected (no groups row).
  post_policy admins_only blocks a non-admin member send.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from sqlalchemy import func, select

import app.services.group_service as group_service_module
from app.api.ws_manager import WsManager
from app.core.enums import (
    ConversationType,
    GroupJoinRequestState,
    GroupMemberDmPolicy,
    GroupMemberState,
    GroupRole,
    MessageType,
)
from app.models import (
    Conversation,
    ConversationMember,
    Group,
    GroupInvite,
    GroupJoinRequest,
    GroupMember,
    Message,
    Notification,
)
from app.services.group_service import GroupService
from tests import helpers


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
async def _mk_user(db, name):
    return await helpers.create_user(db, full_name=name)


async def _create_group(client, headers, **overrides):
    body = {
        "name": "Cardiology Rounds",
        "visibility": "private",
        "join_policy": "request",
        "post_policy": "all_members",
        "member_dm_policy": "request",
    }
    body.update(overrides)
    r = await client.post("/api/v1/groups", json=body, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


async def _headers(user):
    return await helpers.auth_headers(user.id)


@pytest.fixture
async def loopback_group_ws(monkeypatch):
    """Route group_service WS publishes through a local recording manager."""
    manager = WsManager()
    sent: list[dict] = []

    async def loopback(user_ids, event, data):
        for uid in user_ids:
            sent.append({"user_id": uid, "type": event.value, "data": data})

    monkeypatch.setattr(manager, "publish_to_users", loopback)
    monkeypatch.setattr(group_service_module, "ws_manager", manager)
    return SimpleNamespace(manager=manager, sent=sent)


# --------------------------------------------------------------- test 15
async def test_join_request_approve_membership_system_message_notification(
    db, client, loopback_group_ws
):
    owner = await _mk_user(db, "Dr Owner")
    requester = await _mk_user(db, "Dr Requester")
    owner_h = await _headers(owner)
    req_h = await _headers(requester)

    group = await _create_group(client, owner_h, join_policy="request")
    gid = group["id"]
    conv_id = group["conversation_id"]

    # Requester asks to join → a pending request, NOT a membership yet.
    r = await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=req_h)
    assert r.status_code == 200, r.text
    assert r.json()["result"] == "requested"
    assert not await _is_active_member(db, gid, requester.id)

    # Owner was notified (badge) + WS group_join_request fanned out.
    notif = await db.scalar(
        select(Notification).where(
            Notification.user_id == owner.id, Notification.type == "group_join_request"
        )
    )
    assert notif is not None
    assert any(e["type"] == "group_join_request" for e in loopback_group_ws.sent)

    # Owner sees + approves the request.
    listing = await client.get(f"/api/v1/groups/{gid}/join-requests", headers=owner_h)
    assert listing.status_code == 200
    request_id = listing.json()[0]["id"]

    approve = await client.post(
        f"/api/v1/groups/{gid}/join-requests/{request_id}/approve", headers=owner_h
    )
    assert approve.status_code == 200, approve.text

    # Membership formed + mirrored into conversation_members.
    assert await _is_active_member(db, gid, requester.id)
    conv_member = await db.scalar(
        select(ConversationMember).where(
            ConversationMember.conversation_id == conv_id,
            ConversationMember.user_id == requester.id,
        )
    )
    assert conv_member is not None

    # System "joined" message persisted.
    sys_msgs = (
        await db.scalars(
            select(Message).where(
                Message.conversation_id == conv_id, Message.type == MessageType.SYSTEM
            )
        )
    ).all()
    assert any("joined" in _content(m) for m in sys_msgs)

    # Requester notified of approval.
    approved_notif = await db.scalar(
        select(Notification).where(
            Notification.user_id == requester.id,
            Notification.type == "group_join_request_approved",
        )
    )
    assert approved_notif is not None

    # member_count is 2 (owner + requester).
    g = await db.scalar(select(Group).where(Group.id == gid))
    assert g.member_count == 2


async def test_reject_then_14_day_rerequest_cooldown(db, client):
    owner = await _mk_user(db, "Dr Owner")
    requester = await _mk_user(db, "Dr Requester")
    owner_h = await _headers(owner)
    req_h = await _headers(requester)
    group = await _create_group(client, owner_h, join_policy="request")
    gid = group["id"]

    await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=req_h)
    listing = await client.get(f"/api/v1/groups/{gid}/join-requests", headers=owner_h)
    request_id = listing.json()[0]["id"]
    reject = await client.post(
        f"/api/v1/groups/{gid}/join-requests/{request_id}/reject", headers=owner_h
    )
    assert reject.status_code == 200

    # Immediate re-request is blocked by the 14-day cooldown.
    again = await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=req_h)
    assert again.status_code == 429
    assert again.json()["detail"] == "rejoin_cooldown"

    # Age the rejection past the cooldown → re-request allowed.
    jr = await db.scalar(
        select(GroupJoinRequest).where(
            GroupJoinRequest.group_id == gid,
            GroupJoinRequest.state == GroupJoinRequestState.REJECTED,
        )
    )
    jr.decided_at = datetime.now(tz=timezone.utc) - timedelta(days=15)
    await db.commit()
    retry = await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=req_h)
    assert retry.status_code == 200
    assert retry.json()["result"] == "requested"


# --------------------------------------------------------------- test 16
async def test_secret_group_hidden_and_revoked_token_404(db, client):
    owner = await _mk_user(db, "Dr Owner")
    outsider = await _mk_user(db, "Dr Outsider")
    owner_h = await _headers(owner)
    out_h = await _headers(outsider)

    group = await _create_group(
        client, owner_h, visibility="secret", join_policy="invite_only"
    )
    gid = group["id"]

    # GET by a non-member → 404 (indistinguishable from nonexistent).
    r = await client.get(f"/api/v1/groups/{gid}", headers=out_h)
    assert r.status_code == 404

    # Absent from discovery.
    disc = await client.get("/api/v1/groups", headers=out_h)
    assert all(row["id"] != gid for row in disc.json()["data"])

    # But the owner (a member) can see it.
    owner_view = await client.get(f"/api/v1/groups/{gid}", headers=owner_h)
    assert owner_view.status_code == 200

    # A revoked link-invite token 404s on accept.
    inv = await client.post(
        f"/api/v1/groups/{gid}/invites", json={"link": True}, headers=owner_h
    )
    assert inv.status_code == 201, inv.text
    token = inv.json()["token"]
    invite_id = inv.json()["id"]
    revoke = await client.delete(
        f"/api/v1/groups/{gid}/invites/{invite_id}", headers=owner_h
    )
    assert revoke.status_code == 200
    accept = await client.post(f"/api/v1/group-invites/{token}/accept", headers=out_h)
    assert accept.status_code == 404


# --------------------------------------------------------------- test 17
async def test_no_consentless_add_to_group(db, client):
    """Every membership path requires the joiner's own action. There is no
    endpoint that force-adds a user; an invite only forms membership on accept."""
    org = await helpers.create_org(db)
    owner = await _mk_user(db, "Dr Owner")
    colleague = await _mk_user(db, "Dr Colleague")
    await helpers.add_org_member(db, org, owner)
    await helpers.add_org_member(db, org, colleague)
    stranger = await _mk_user(db, "Dr Stranger")  # different (no) org, unconnected

    owner_h = await _headers(owner)
    colleague_h = await _headers(colleague)
    group = await _create_group(client, owner_h, join_policy="invite_only")
    gid = group["id"]

    # Inviting a same-org colleague is allowed BUT does not add them — pending.
    inv = await client.post(
        f"/api/v1/groups/{gid}/invites",
        json={"user_id": str(colleague.id)},
        headers=owner_h,
    )
    assert inv.status_code == 201, inv.text
    assert not await _is_active_member(db, gid, colleague.id)
    invite_id = inv.json()["id"]

    # Only the invitee's OWN accept forms membership.
    accept = await client.post(
        f"/api/v1/groups/{gid}/invites/{invite_id}/accept", headers=colleague_h
    )
    assert accept.status_code == 200
    assert await _is_active_member(db, gid, colleague.id)

    # A stranger (not connected, no shared org) cannot even be invited.
    inv2 = await client.post(
        f"/api/v1/groups/{gid}/invites",
        json={"user_id": str(stranger.id)},
        headers=owner_h,
    )
    assert inv2.status_code == 403
    assert inv2.json()["detail"] == "not_invitable"

    # invite_only self-join is refused.
    stranger_h = await _headers(stranger)
    self_join = await client.post(
        f"/api/v1/groups/{gid}/join", json={}, headers=stranger_h
    )
    assert self_join.status_code == 403
    assert self_join.json()["detail"] == "join_by_invite_only"


# --------------------------------------------------------------- test 18
async def test_owner_cannot_leave_without_transfer(db, client):
    org = await helpers.create_org(db)
    owner = await _mk_user(db, "Dr Owner")
    heir = await _mk_user(db, "Dr Heir")
    await helpers.add_org_member(db, org, owner)
    await helpers.add_org_member(db, org, heir)
    owner_h = await _headers(owner)

    group = await _create_group(client, owner_h, join_policy="open")
    gid = group["id"]
    # Bring heir in.
    heir_h = await _headers(heir)
    await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=heir_h)

    # Owner leaving is refused.
    leave = await client.delete(
        f"/api/v1/groups/{gid}/members/{owner.id}", headers=owner_h
    )
    assert leave.status_code == 409
    assert leave.json()["detail"] == "owner_must_transfer"

    # Transfer, then the (now ex-owner) admin may leave.
    transfer = await client.post(
        f"/api/v1/groups/{gid}/transfer-ownership",
        json={"user_id": str(heir.id)},
        headers=owner_h,
    )
    assert transfer.status_code == 200
    g = await db.scalar(select(Group).where(Group.id == gid))
    assert g.owner_id == heir.id
    leave2 = await client.delete(
        f"/api/v1/groups/{gid}/members/{owner.id}", headers=owner_h
    )
    assert leave2.status_code == 200
    assert not await _is_active_member(db, gid, owner.id)


# --------------------------------------------------------------- test 13
async def test_unconnected_members_can_both_post(db, client):
    owner = await _mk_user(db, "Dr Owner")
    a = await _mk_user(db, "Dr A")  # different orgs, unconnected to each other
    b = await _mk_user(db, "Dr B")
    owner_h = await _headers(owner)
    group = await _create_group(client, owner_h, join_policy="open")
    gid, conv_id = group["id"], group["conversation_id"]

    for u in (a, b):
        h = await _headers(u)
        j = await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=h)
        assert j.status_code == 200

    # Neither is connected to the other, but membership grants posting rights.
    for u in (a, b):
        h = await _headers(u)
        send = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"content": "hello team"},
            headers=h,
        )
        assert send.status_code == 200, send.text


# --------------------------------------------------- member_dm_policy matrix
@pytest.mark.parametrize(
    "policy,expected",
    [
        (GroupMemberDmPolicy.OPEN, "open"),
        (GroupMemberDmPolicy.REQUEST, "request"),
        (GroupMemberDmPolicy.DISABLED, "denied"),
    ],
)
async def test_member_dm_policy_gate(db, client, policy, expected):
    owner = await _mk_user(db, "Dr Owner")
    member = await _mk_user(db, "Dr Member")
    owner_h = await _headers(owner)
    group_json = await _create_group(
        client, owner_h, join_policy="open", member_dm_policy=policy.value
    )
    gid = group_json["id"]
    member_h = await _headers(member)
    await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=member_h)

    group = await db.scalar(select(Group).where(Group.id == gid))
    decision = await GroupService.group_dm_decision(
        group=group, actor_id=member.id, target_id=owner.id, db=db
    )
    assert decision == expected


# --------------------------------------------------------------- test 20
async def test_group_read_by_and_unread_at_many_members(db, client):
    owner = await _mk_user(db, "Dr Owner")
    owner_h = await _headers(owner)
    group_json = await _create_group(client, owner_h, join_policy="open")
    gid, conv_id = group_json["id"], group_json["conversation_id"]
    group = await db.scalar(select(Group).where(Group.id == gid))

    members = [await _mk_user(db, f"Dr M{i}") for i in range(12)]
    await _add_members_directly(db, group, members)

    # Owner posts one message.
    send = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "all-hands"},
        headers=owner_h,
    )
    assert send.status_code == 200

    # A member has 1 unread before reading (A3 seq-cursor path).
    m0_h = await _headers(members[0])
    listing = await client.get("/api/v1/conversations", headers=m0_h)
    row = next(c for c in listing.json() if c["id"] == conv_id)
    assert row["unread_count"] == 1

    # Every member marks the conversation read → owner's message is "read by all".
    for m in members:
        h = await _headers(m)
        rd = await client.post(f"/api/v1/conversations/{conv_id}/read", headers=h)
        assert rd.status_code == 200

    msgs = await client.get(
        f"/api/v1/conversations/{conv_id}/messages", headers=owner_h
    )
    text_msg = next(mm for mm in msgs.json() if mm["type"] == "text")
    assert text_msg["read"] is True

    # And that member's unread is now 0.
    listing2 = await client.get("/api/v1/conversations", headers=m0_h)
    row2 = next(c for c in listing2.json() if c["id"] == conv_id)
    assert row2["unread_count"] == 0


# --------------------------------------------------- legacy org group chats
async def test_legacy_org_group_chat_unaffected(db, client):
    """A plain type=group org conversation (no groups row) behaves exactly as
    before — no post-policy gate, no group linkage."""
    org = await helpers.create_org(db)
    a = await _mk_user(db, "Dr A")
    b = await _mk_user(db, "Dr B")
    await helpers.add_org_member(db, org, a)
    await helpers.add_org_member(db, org, b)
    conv = await helpers.create_conversation(
        db, org, [a, b], conv_type=ConversationType.GROUP, name="Ward Team"
    )
    # No groups row exists for this conversation.
    linked = await db.scalar(select(Group).where(Group.conversation_id == conv.id))
    assert linked is None

    a_h = await _headers(a)
    send = await client.post(
        f"/api/v1/conversations/{conv.id}/messages",
        json={"content": "legacy still works"},
        headers=a_h,
    )
    assert send.status_code == 200, send.text


# --------------------------------------------------- post_policy admins_only
async def test_post_policy_admins_only_blocks_member(db, client):
    owner = await _mk_user(db, "Dr Owner")
    member = await _mk_user(db, "Dr Member")
    owner_h = await _headers(owner)
    group = await _create_group(
        client, owner_h, join_policy="open", post_policy="admins_only"
    )
    gid, conv_id = group["id"], group["conversation_id"]
    member_h = await _headers(member)
    await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=member_h)

    # Non-admin member is blocked.
    blocked = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "may I speak?"},
        headers=member_h,
    )
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "post_restricted"

    # Owner (admin-tier) may post.
    ok = await client.post(
        f"/api/v1/conversations/{conv_id}/messages",
        json={"content": "announcement"},
        headers=owner_h,
    )
    assert ok.status_code == 200


# --------------------------------------------------- role capability sanity
async def test_role_matrix_admin_cannot_grant_admin(db, client):
    owner = await _mk_user(db, "Dr Owner")
    admin = await _mk_user(db, "Dr Admin")
    member = await _mk_user(db, "Dr Member")
    owner_h = await _headers(owner)
    group = await _create_group(client, owner_h, join_policy="open")
    gid = group["id"]
    for u in (admin, member):
        h = await _headers(u)
        await client.post(f"/api/v1/groups/{gid}/join", json={}, headers=h)

    # Owner promotes `admin` to admin.
    promote = await client.patch(
        f"/api/v1/groups/{gid}/members/{admin.id}",
        json={"role": "admin"},
        headers=owner_h,
    )
    assert promote.status_code == 200

    # An admin may promote a member to moderator...
    admin_h = await _headers(admin)
    mod = await client.patch(
        f"/api/v1/groups/{gid}/members/{member.id}",
        json={"role": "moderator"},
        headers=admin_h,
    )
    assert mod.status_code == 200

    # ...but may NOT grant admin (owner-only).
    grant = await client.patch(
        f"/api/v1/groups/{gid}/members/{member.id}",
        json={"role": "admin"},
        headers=admin_h,
    )
    assert grant.status_code == 403
    assert grant.json()["detail"] == "owner_only"


# --------------------------------------------------------------------------- #
# small internal helpers
# --------------------------------------------------------------------------- #
def _content(msg: Message) -> str:
    from app.core.security import decrypt_message

    return decrypt_message(msg.content_encrypted) if msg.content_encrypted else ""


async def _is_active_member(db, group_id, user_id) -> bool:
    m = await db.scalar(
        select(GroupMember).where(
            GroupMember.group_id == group_id, GroupMember.user_id == user_id
        )
    )
    return m is not None and m.state == GroupMemberState.ACTIVE


async def _add_members_directly(db, group: Group, users) -> None:
    """Add many active members straight to the DB (mirrors _sync_member) so the
    receipts test can scale without N join round-trips."""
    for u in users:
        db.add(
            GroupMember(
                group_id=group.id,
                user_id=u.id,
                role=GroupRole.MEMBER,
                state=GroupMemberState.ACTIVE,
            )
        )
        db.add(ConversationMember(conversation_id=group.conversation_id, user_id=u.id))
    n = await db.scalar(
        select(func.count())
        .select_from(GroupMember)
        .where(GroupMember.group_id == group.id)
    )
    group.member_count = int(n or 0)
    await db.commit()
