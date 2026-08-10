"""M2 people-search integration tests — spec §16 acceptance 7–9 (adapted).

Covers: search excludes blocked (bidirectional) + discoverability='connections'
non-connections; degree labels correct; NPI/phone/email absent from EVERY card
(regression); rate-limit 429 after quota. The search service runs WITHOUT the
pg_trgm extension here (Base.metadata.create_all builds the schema; ILIKE
fallback path), which is itself the trgm-vs-ILIKE coverage.
"""
from __future__ import annotations

import pytest
from sqlalchemy import select

from app.core import constants
from app.models import Block, Connection, UserPrivacySettings
from app.services.relationship_service import RelationshipService
from tests import helpers

PEOPLE = "/api/v1/people"

# Fields that must NEVER appear in a directory payload (HIPAA hard rule).
FORBIDDEN = {"phone", "email", "npi_number", "npi"}


async def _user(db, org, name, **kw):
    u = await helpers.create_user(db, full_name=name, **kw)
    if org is not None:
        await helpers.add_org_member(db, org, u)
    return u, await helpers.auth_headers(u.id)


async def _connect(db, a, b):
    """Direct edge insert (mirrored rows + shared pair_id) + cache."""
    import uuid

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
# Acceptance 7 — basic search returns discoverable users, excludes self
# --------------------------------------------------------------------------- #
async def test_search_finds_by_name_excludes_self(client, db):
    org = await helpers.create_org(db)
    alice, ah = await _user(db, org, "Alice Cardio", specialty="Cardiology")
    bob, bh = await _user(db, org, "Bob Neuro", specialty="Neurology")

    r = await client.get(f"{PEOPLE}/search?q=Cardio", headers=bh)
    assert r.status_code == 200, r.text
    ids = [c["id"] for c in r.json()["data"]]
    assert str(alice.id) in ids
    # Searching for self-excluding: Alice searching her own name never sees self.
    r2 = await client.get(f"{PEOPLE}/search?q=Alice", headers=ah)
    assert str(alice.id) not in [c["id"] for c in r2.json()["data"]]


# --------------------------------------------------------------------------- #
# Acceptance 8 — degree labels: 1st for connected, 2nd for friend-of-friend
# --------------------------------------------------------------------------- #
async def test_degree_labels(client, db):
    org = await helpers.create_org(db)
    a, ah = await _user(db, org, "Dr A")
    b, bh = await _user(db, org, "Dr B")
    c, ch = await _user(db, org, "Dr C")
    await _connect(db, a, b)
    await _connect(db, b, c)

    r = await client.get(f"{PEOPLE}/search?q=Dr", headers=ah)
    cards = {c["full_name"]: c for c in r.json()["data"]}
    assert cards["Dr B"]["degree"] == "1st"
    assert cards["Dr C"]["degree"] == "2nd"
    # B is a mutual between A and C.
    assert cards["Dr C"]["mutual_count"] == 1


# --------------------------------------------------------------------------- #
# Acceptance 9a — blocked users excluded bidirectionally
# --------------------------------------------------------------------------- #
async def test_search_excludes_blocked_bidirectional(client, db):
    org = await helpers.create_org(db)
    a, ah = await _user(db, org, "Alpha Doc")
    b, bh = await _user(db, org, "Beta Doc")

    # A blocks B.
    db.add(Block(blocker_id=a.id, blocked_id=b.id))
    await db.commit()

    # A cannot see B...
    r1 = await client.get(f"{PEOPLE}/search?q=Beta", headers=ah)
    assert str(b.id) not in [c["id"] for c in r1.json()["data"]]
    # ...and B cannot see A (bidirectional).
    r2 = await client.get(f"{PEOPLE}/search?q=Alpha", headers=bh)
    assert str(a.id) not in [c["id"] for c in r2.json()["data"]]


# --------------------------------------------------------------------------- #
# Acceptance 9b — discoverability='connections' hidden from non-connections
# --------------------------------------------------------------------------- #
async def test_discoverability_connections_hidden_from_stranger(client, db):
    org = await helpers.create_org(db)
    a, ah = await _user(db, org, "Dr Seeker")
    hidden, _ = await _user(db, org, "Dr Hidden")
    db.add(UserPrivacySettings(user_id=hidden.id, discoverability="connections"))
    await db.commit()

    # Stranger cannot find a connections-only user.
    r = await client.get(f"{PEOPLE}/search?q=Hidden", headers=ah)
    assert str(hidden.id) not in [c["id"] for c in r.json()["data"]]

    # But a first-degree connection can.
    await _connect(db, a, hidden)
    r2 = await client.get(f"{PEOPLE}/search?q=Hidden", headers=ah)
    assert str(hidden.id) in [c["id"] for c in r2.json()["data"]]


async def test_discoverability_nobody_hidden_from_everyone(client, db):
    org = await helpers.create_org(db)
    a, ah = await _user(db, org, "Dr Seeker")
    ghost, _ = await _user(db, org, "Dr Ghost")
    db.add(UserPrivacySettings(user_id=ghost.id, discoverability="nobody"))
    await db.commit()
    r = await client.get(f"{PEOPLE}/search?q=Ghost", headers=ah)
    assert str(ghost.id) not in [c["id"] for c in r.json()["data"]]


# --------------------------------------------------------------------------- #
# Filters — specialty, state, degree
# --------------------------------------------------------------------------- #
async def test_filters_specialty_state_degree(client, db):
    org = await helpers.create_org(db)
    seeker, sh = await _user(db, org, "Dr Seeker")
    cardio_ca, _ = await _user(db, org, "Dr Heart", specialty="Cardiology", state="CA")
    cardio_ny, _ = await _user(db, org, "Dr Pulse", specialty="Cardiology", state="NY")
    neuro_ca, _ = await _user(db, org, "Dr Brain", specialty="Neurology", state="CA")

    r = await client.get(f"{PEOPLE}/search?specialty=Cardiology", headers=sh)
    ids = {c["id"] for c in r.json()["data"]}
    assert {str(cardio_ca.id), str(cardio_ny.id)} <= ids
    assert str(neuro_ca.id) not in ids

    r2 = await client.get(f"{PEOPLE}/search?specialty=Cardiology&state=CA", headers=sh)
    ids2 = {c["id"] for c in r2.json()["data"]}
    assert ids2 == {str(cardio_ca.id)}

    # degree=1 with no connections → empty.
    r3 = await client.get(f"{PEOPLE}/search?degree=1", headers=sh)
    assert r3.json()["data"] == []


# --------------------------------------------------------------------------- #
# Org directory visibility — org_only hidden from non-colleagues
# --------------------------------------------------------------------------- #
async def test_org_only_directory_hidden_from_outsider(client, db):
    org_private = await helpers.create_org(db)
    org_private.directory_visibility = "org_only"
    org_public = await helpers.create_org(db)
    await db.commit()

    insider, ih = await _user(db, org_private, "Dr Insider")
    outsider, oh = await _user(db, org_public, "Dr Outsider")

    # Outsider (shares no org) cannot see the org_only member.
    r = await client.get(f"{PEOPLE}/search?q=Insider", headers=oh)
    assert str(insider.id) not in [c["id"] for c in r.json()["data"]]

    # A colleague in the same org still sees them.
    colleague, ch = await _user(db, org_private, "Dr Colleague")
    r2 = await client.get(f"{PEOPLE}/search?q=Insider", headers=ch)
    assert str(insider.id) in [c["id"] for c in r2.json()["data"]]


# --------------------------------------------------------------------------- #
# HIPAA regression — NO phone/email/npi in ANY card (introspect JSON keys)
# --------------------------------------------------------------------------- #
async def test_no_phi_in_search_payload(client, db):
    org = await helpers.create_org(db)
    seeker, sh = await _user(db, org, "Dr Seeker")
    await _user(db, org, "Dr Target", specialty="Cardiology", city="Austin", state="TX")

    r = await client.get(f"{PEOPLE}/search?q=Target", headers=sh)
    assert r.status_code == 200
    cards = r.json()["data"]
    assert cards, "expected at least one card"
    for card in cards:
        assert FORBIDDEN.isdisjoint(card.keys()), f"PHI leaked: {card.keys()}"


# --------------------------------------------------------------------------- #
# Rate limit — 429 after the per-minute quota (monkeypatch the constant)
# --------------------------------------------------------------------------- #
async def test_search_rate_limited(client, db, monkeypatch):
    monkeypatch.setattr(constants, "PEOPLE_SEARCH_PER_MINUTE", 3)
    # The endpoint reads the constant at call time via the imported name in
    # people.py — patch there too.
    import app.api.v1.people as people_mod

    monkeypatch.setattr(people_mod, "PEOPLE_SEARCH_PER_MINUTE", 3)
    org = await helpers.create_org(db)
    _, sh = await _user(db, org, "Dr Seeker")

    for _ in range(3):
        assert (await client.get(f"{PEOPLE}/search?q=x", headers=sh)).status_code == 200
    over = await client.get(f"{PEOPLE}/search?q=x", headers=sh)
    assert over.status_code == 429
    assert over.json()["detail"] == "rate_limited"


# --------------------------------------------------------------------------- #
# Cursor pagination — second page continues via next_cursor
# --------------------------------------------------------------------------- #
async def test_cursor_pagination(client, db):
    org = await helpers.create_org(db)
    _, sh = await _user(db, org, "Dr Seeker")
    for i in range(5):
        await _user(db, org, f"Page Doc {i}")

    r = await client.get(f"{PEOPLE}/search?q=Page&limit=2", headers=sh)
    body = r.json()
    assert len(body["data"]) == 2
    assert body["next_cursor"] is not None

    r2 = await client.get(
        f"{PEOPLE}/search?q=Page&limit=2&cursor={body['next_cursor']}", headers=sh
    )
    first_ids = {c["id"] for c in body["data"]}
    second_ids = {c["id"] for c in r2.json()["data"]}
    assert first_ids.isdisjoint(second_ids)
