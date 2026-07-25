"""M2 public-profile integration tests.

Covers: PublicProfileOut shape; connection_state + can_message; profile of a
blocker → 404 user_unavailable (silence rule); non-existent → 404; NPI/phone/
email absent from the profile payload (regression); handle uniqueness 409.
"""
from __future__ import annotations

import uuid

from app.models import Block, Connection, ConnectionInvitation
from app.services.relationship_service import RelationshipService
from tests import helpers

USERS = "/api/v1/users"
FORBIDDEN = {"phone", "email", "npi_number", "npi"}


async def _user(db, org, name, **kw):
    u = await helpers.create_user(db, full_name=name, **kw)
    if org is not None:
        await helpers.add_org_member(db, org, u)
    return u, await helpers.auth_headers(u.id)


async def _connect(db, a, b):
    pair = uuid.uuid4()
    db.add_all(
        [
            Connection(user_id=a.id, connected_user_id=b.id, pair_id=pair),
            Connection(user_id=b.id, connected_user_id=a.id, pair_id=pair),
        ]
    )
    await db.commit()
    await RelationshipService.add_edge_cache(a.id, b.id)


# --------------------------------------------------------------------------- #
# Happy path — colleague profile is viewable, message mode open, no PHI
# --------------------------------------------------------------------------- #
async def test_profile_colleague_open(client, db):
    org = await helpers.create_org(db)
    viewer, vh = await _user(db, org, "Dr Viewer")
    target, _ = await _user(
        db,
        org,
        "Dr Target",
        specialty="Cardiology",
        city="Austin",
        state="TX",
        headline="Interventional cardiologist",
    )

    r = await client.get(f"{USERS}/{target.id}/profile", headers=vh)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["full_name"] == "Dr Target"
    assert body["headline"] == "Interventional cardiologist"
    assert body["location_label"] == "Austin, TX"
    assert body["about"] is None  # bio unset
    assert body["can_message"] == "open"  # same-org colleague
    assert body["connection_state"] == "none"
    assert body["context_label"] == "You share an organization"
    assert FORBIDDEN.isdisjoint(body.keys())


# --------------------------------------------------------------------------- #
# connection_state transitions
# --------------------------------------------------------------------------- #
async def test_profile_connection_states(client, db):
    org = await helpers.create_org(db)
    viewer, vh = await _user(db, org, "Dr Viewer")
    other, oh = await _user(db, org, "Dr Other")

    # Outgoing pending invite.
    db.add(ConnectionInvitation(sender_id=viewer.id, recipient_id=other.id, status="pending"))
    await db.commit()
    r = await client.get(f"{USERS}/{other.id}/profile", headers=vh)
    assert r.json()["connection_state"] == "pending_outgoing"
    # From the other side it reads as incoming.
    r2 = await client.get(f"{USERS}/{viewer.id}/profile", headers=oh)
    assert r2.json()["connection_state"] == "pending_incoming"

    # Once connected.
    await db.execute(ConnectionInvitation.__table__.delete())
    await db.commit()
    await _connect(db, viewer, other)
    r3 = await client.get(f"{USERS}/{other.id}/profile", headers=vh)
    assert r3.json()["connection_state"] == "connected"
    assert r3.json()["degree"] == "1st"


# --------------------------------------------------------------------------- #
# Profile of a blocker → 404 user_unavailable (silence rule)
# --------------------------------------------------------------------------- #
async def test_profile_of_blocker_is_404(client, db):
    org = await helpers.create_org(db)
    viewer, vh = await _user(db, org, "Dr Viewer")
    blocker, _ = await _user(db, org, "Dr Blocker")

    # blocker blocks viewer.
    db.add(Block(blocker_id=blocker.id, blocked_id=viewer.id))
    await db.commit()

    r = await client.get(f"{USERS}/{blocker.id}/profile", headers=vh)
    assert r.status_code == 404
    assert r.json()["detail"] == "user_unavailable"


async def test_profile_nonexistent_is_404(client, db):
    org = await helpers.create_org(db)
    _, vh = await _user(db, org, "Dr Viewer")
    r = await client.get(f"{USERS}/{uuid.uuid4()}/profile", headers=vh)
    assert r.status_code == 404
    assert r.json()["detail"] == "user_unavailable"


# --------------------------------------------------------------------------- #
# discoverability='nobody' stranger → 404; but colleague still sees them
# --------------------------------------------------------------------------- #
async def test_profile_not_discoverable_stranger_404(client, db):
    from app.models import UserPrivacySettings

    org_a = await helpers.create_org(db)
    org_b = await helpers.create_org(db)
    viewer, vh = await _user(db, org_a, "Dr Viewer")
    private, _ = await _user(db, org_b, "Dr Private")
    db.add(UserPrivacySettings(user_id=private.id, discoverability="nobody"))
    await db.commit()

    r = await client.get(f"{USERS}/{private.id}/profile", headers=vh)
    assert r.status_code == 404


# --------------------------------------------------------------------------- #
# HIPAA regression — NO phone/email/npi in the profile payload
# --------------------------------------------------------------------------- #
async def test_no_phi_in_profile_payload(client, db):
    org = await helpers.create_org(db)
    _, vh = await _user(db, org, "Dr Viewer")
    target, _ = await _user(db, org, "Dr Target", specialty="Cardiology")

    r = await client.get(f"{USERS}/{target.id}/profile", headers=vh)
    assert r.status_code == 200
    assert FORBIDDEN.isdisjoint(r.json().keys())


# --------------------------------------------------------------------------- #
# handle: set on PATCH /me, uniqueness → 409 handle_taken, charset validation
# --------------------------------------------------------------------------- #
async def test_handle_set_and_uniqueness(client, db):
    org = await helpers.create_org(db)
    a, ah = await _user(db, org, "Dr A")
    b, bh = await _user(db, org, "Dr B")

    r = await client.patch(f"{USERS}/me", json={"handle": "dr_house"}, headers=ah)
    assert r.status_code == 200, r.text
    assert r.json()["handle"] == "dr_house"

    # B cannot take the same handle.
    dup = await client.patch(f"{USERS}/me", json={"handle": "dr_house"}, headers=bh)
    assert dup.status_code == 409
    assert dup.json()["detail"] == "handle_taken"

    # Invalid charset rejected at validation (422).
    bad = await client.patch(f"{USERS}/me", json={"handle": "Dr House!"}, headers=bh)
    assert bad.status_code == 422


async def test_handle_and_headline_roundtrip(client, db):
    org = await helpers.create_org(db)
    _, ah = await _user(db, org, "Dr A")
    r = await client.patch(
        f"{USERS}/me",
        json={"handle": "cardio_ace", "headline": "Heart specialist"},
        headers=ah,
    )
    assert r.status_code == 200
    body = r.json()
    assert body["handle"] == "cardio_ace"
    assert body["headline"] == "Heart specialist"
