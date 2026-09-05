"""Pure unit tests for the security boundary (app/core/permissions.py).

No DB, no Redis — exhaustive branch coverage of the decision table.
"""
from __future__ import annotations

import uuid

from app.core.enums import Discoverability, DmPolicy, InvitePolicy
from app.core.permissions import (
    Decision,
    PrivacySnapshot,
    RelationshipContext,
    can_add_to_group,
    can_message,
    can_send_invitation,
    can_start_direct,
    can_view_profile,
)

A = uuid.uuid4()
B = uuid.uuid4()
ORG = uuid.uuid4()


def ctx(**kw) -> RelationshipContext:
    base = dict(viewer_id=A, target_id=B)
    base.update(kw)
    return RelationshipContext(**base)


def priv(**kw) -> PrivacySnapshot:
    return PrivacySnapshot(**kw)


# --------------------------------------------------------------------------- #
# can_view_profile
# --------------------------------------------------------------------------- #
def test_view_blocked_denied():
    d = can_view_profile(ctx(is_blocked_either_way=True))
    assert not d.allowed and d.mode == "denied" and d.reason == "blocked"


def test_view_colleague_open():
    assert can_view_profile(ctx(shared_org_ids=frozenset({ORG}))).mode == "open"


def test_view_connection_open():
    assert can_view_profile(ctx(is_first_degree=True)).mode == "open"


def test_view_everyone_open():
    d = can_view_profile(ctx(target_privacy=priv(discoverability=Discoverability.EVERYONE)))
    assert d.mode == "open"


def test_view_connections_only_denied():
    d = can_view_profile(ctx(target_privacy=priv(discoverability=Discoverability.CONNECTIONS)))
    assert not d.allowed and d.reason == "not_discoverable"


def test_view_nobody_denied():
    d = can_view_profile(ctx(target_privacy=priv(discoverability=Discoverability.NOBODY)))
    assert not d.allowed


# --------------------------------------------------------------------------- #
# can_send_invitation
# --------------------------------------------------------------------------- #
def test_invite_blocked():
    assert can_send_invitation(ctx(is_blocked_either_way=True)).reason == "blocked"


def test_invite_self():
    assert can_send_invitation(ctx(target_id=A)).reason == "self"


def test_invite_already_connected():
    assert can_send_invitation(ctx(is_first_degree=True)).reason == "already_connected"


def test_invite_pending_exists():
    assert can_send_invitation(ctx(has_pending_invitation=True)).reason == "invitation_exists"


def test_invite_colleague_open_regardless_of_killswitch():
    # Colleagues connect even with external networking off (internal path).
    d = can_send_invitation(
        ctx(shared_org_ids=frozenset({ORG}), external_networking_enabled_for_both=False)
    )
    assert d.allowed and d.mode == "open"


def test_invite_external_disabled():
    d = can_send_invitation(ctx(external_networking_enabled_for_both=False))
    assert not d.allowed and d.reason == "networking_disabled"


def test_invite_policy_nobody():
    d = can_send_invitation(ctx(target_privacy=priv(invite_policy=InvitePolicy.NOBODY)))
    assert not d.allowed and d.reason == "invite_policy_nobody"


def test_invite_policy_shared_only_denied_without_org():
    d = can_send_invitation(
        ctx(target_privacy=priv(invite_policy=InvitePolicy.SHARED_GROUP_OR_ORG))
    )
    assert not d.allowed and d.reason == "invite_policy_shared_only"


def test_invite_policy_second_degree_denied_for_stranger():
    d = can_send_invitation(
        ctx(target_privacy=priv(invite_policy=InvitePolicy.SECOND_DEGREE))
    )
    assert not d.allowed and d.reason == "invite_policy_second_degree"


def test_invite_everyone_open():
    d = can_send_invitation(ctx(target_privacy=priv(invite_policy=InvitePolicy.EVERYONE)))
    assert d.allowed and d.mode == "open"


# --------------------------------------------------------------------------- #
# can_start_direct / _direct_decision
# --------------------------------------------------------------------------- #
def test_direct_blocked():
    assert can_start_direct(ctx(is_blocked_either_way=True)).reason == "blocked"


def test_direct_self():
    assert can_start_direct(ctx(target_id=A)).reason == "self"


def test_direct_colleague_open():
    # Acceptance test 6: same-org colleagues ALWAYS open, regardless of state.
    d = can_start_direct(
        ctx(
            shared_org_ids=frozenset({ORG}),
            external_networking_enabled_for_both=False,
            target_privacy=priv(dm_policy=DmPolicy.NOBODY),
        )
    )
    assert d.mode == "open"


def test_direct_connection_open():
    assert can_start_direct(ctx(is_first_degree=True)).mode == "open"


def test_direct_stranger_denied_regardless_of_policy_or_flags():
    """No request tier: a stranger is denied even with the most permissive
    DM policy, networking on, and a previously open thread."""
    for kw in (
        {},
        {"target_privacy": priv(dm_policy=DmPolicy.EVERYONE)},
        {"target_privacy": priv(dm_policy=DmPolicy.CONNECTIONS_AND_REQUESTS)},
        {"existing_conversation_access": "open"},
        {"external_networking_enabled_for_both": False},
    ):
        d = can_start_direct(ctx(**kw))
        assert not d.allowed and d.reason == "not_connected", kw


# --------------------------------------------------------------------------- #
# can_message — same table as can_start_direct
# --------------------------------------------------------------------------- #
def test_message_connection_open():
    assert can_message(ctx(is_first_degree=True)).mode == "open"


def test_message_colleague_open():
    assert can_message(ctx(shared_org_ids=frozenset({ORG}))).mode == "open"


def test_message_stranger_denied_even_with_pending_thread():
    d = can_message(ctx(existing_conversation_access="pending_request"))
    assert not d.allowed and d.reason == "not_connected"


def test_message_blocked_denied():
    d = can_message(ctx(is_first_degree=True, is_blocked_either_way=True))
    assert not d.allowed and d.reason == "blocked"


# --------------------------------------------------------------------------- #
# can_add_to_group
# --------------------------------------------------------------------------- #
def test_group_blocked():
    assert can_add_to_group(ctx(is_blocked_either_way=True)).reason == "blocked"


def test_group_self():
    assert can_add_to_group(ctx(target_id=A)).reason == "self"


def test_group_colleague_or_connection_open():
    assert can_add_to_group(ctx(is_first_degree=True)).mode == "open"
    assert can_add_to_group(ctx(shared_org_ids=frozenset({ORG}))).mode == "open"


def test_group_external_disabled():
    d = can_add_to_group(ctx(external_networking_enabled_for_both=False))
    assert not d.allowed and d.reason == "networking_disabled"


def test_group_not_connected_denied():
    d = can_add_to_group(ctx())
    assert not d.allowed and d.reason == "not_connected"


# --------------------------------------------------------------------------- #
# Decision helpers
# --------------------------------------------------------------------------- #
def test_decision_factories():
    assert Decision.open().mode == "open"
    assert Decision.request().mode == "request"
    assert Decision.denied("x").mode == "denied" and Decision.denied("x").reason == "x"
