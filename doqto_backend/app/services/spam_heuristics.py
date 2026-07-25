"""Spam / abuse heuristics.

M1 shipped the stub; M4 enforces it for the message-request tier. Two seams:

  1. `contains_contact_info` — the send guard rejects an opening request message
     that tries to smuggle a URL or phone number (the classic "call me / visit
     this link" spam pattern) before any request reaches a recipient.
  2. `request_spam_score` / `is_hidden_request` — a cheap, deterministic score
     (no ML) that routes a low-quality request to "hidden": no push, no badge.
     Computed on read (no migration) from the opening message + sender age +
     shared context.

Real velocity/reputation scoring is deferred (M7). Everything here is pure so
callers have a single, unit-testable seam.
"""
from __future__ import annotations

import re

from app.core.constants import NEW_ACCOUNT_REQUEST_DAYS, REQUEST_HIDDEN_THRESHOLD
from app.core.permissions import RelationshipContext

# Accounts younger than this are "new" for the purposes of soft spam signals.
NEW_ACCOUNT_DAYS = 2

# URL or phone number in free text. Matches http(s)://, bare www., or a run of
# 8+ phone-ish characters (digits with optional +, spaces, dashes, parens/dots).
CONTACT_INFO_RE = re.compile(r"https?://|www\.|\+?\d[\d\s().-]{7,}")


def contains_contact_info(text: str | None) -> bool:
    """True if the text smuggles a URL or phone number."""
    if not text:
        return False
    return CONTACT_INFO_RE.search(text) is not None


def is_suspicious_invitation(ctx: RelationshipContext) -> bool:
    """True if an invitation looks spammy enough to warrant extra friction.

    Never blocks on its own (advisory only) — colleagues and connections are
    always fine; a brand-new external account with no shared org is the only
    weak signal today.
    """
    if ctx.shared_org_ids or ctx.is_first_degree:
        return False
    return ctx.target_account_age_days < NEW_ACCOUNT_DAYS


def request_spam_score(
    *,
    content: str | None,
    sender_account_age_days: int,
    has_shared_context: bool,
) -> int:
    """Deterministic 0–3 spam score for a message request's opening message."""
    score = 0
    if contains_contact_info(content):
        score += 1
    if sender_account_age_days < NEW_ACCOUNT_REQUEST_DAYS:
        score += 1
    if not has_shared_context:
        score += 1
    return score


def is_hidden_request(
    *,
    content: str | None,
    sender_account_age_days: int,
    has_shared_context: bool,
) -> bool:
    """Whether a request should be hidden (no push, no badge)."""
    return (
        request_spam_score(
            content=content,
            sender_account_age_days=sender_account_age_days,
            has_shared_context=has_shared_context,
        )
        >= REQUEST_HIDDEN_THRESHOLD
    )
