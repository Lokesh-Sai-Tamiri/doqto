"""Spam / abuse heuristics (M1 stub).

Real scoring (velocity, reputation, ML) is M4/M7. For now this centralises the
one cheap signal we have — brand-new accounts sending unsolicited invitations —
so callers have a single seam to harden later.
"""
from __future__ import annotations

from app.core.permissions import RelationshipContext

# Accounts younger than this are "new" for the purposes of soft spam signals.
NEW_ACCOUNT_DAYS = 2


def is_suspicious_invitation(ctx: RelationshipContext) -> bool:
    """True if an invitation looks spammy enough to warrant extra friction.

    M1: never blocks on its own (returns advisory only) — colleagues and
    connections are always fine; a brand-new external account with no shared
    org is the only weak signal today.
    """
    if ctx.shared_org_ids or ctx.is_first_degree:
        return False
    return ctx.target_account_age_days < NEW_ACCOUNT_DAYS


def is_suspicious_message_request(ctx: RelationshipContext) -> bool:
    """Placeholder for the M4 request-tier send guard."""
    return is_suspicious_invitation(ctx)
