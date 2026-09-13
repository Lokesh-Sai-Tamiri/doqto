# Plan picker

Onboarding ends with a plan picker instead of org selection:

```
Phone → OTP → Your details → Choose your plan → Chats
```

## What it is, and isn't

Presentation only. **Nothing is charged and the choice is not persisted** — the
screen exists so the flow is right; the billing behind it is a separate piece
of work.

That deferral is deliberate rather than lazy. On iOS, unlocking app features
has to go through StoreKit — Apple rejects card entry for digital access under
guideline 3.1.1, and this app already has six rejections behind it (see
`docs/ios-release.md`). Picking a provider is a decision with App Review
consequences, so the UI ships first and the transaction lands once that call is
made. When it does, `_plans` in `payments_screen.dart` becomes the product list
and `_leave` starts the purchase.

## Stage

`AuthStage.needsPayment` sits between `needsRegistration` and the rest.

It is **only ever set by `completeRegistration`**. `bootstrap()` never returns
it, because there is no server-side record of a plan to check — so a returning
user is never shown the picker again. Once billing is real, that is the line
that changes: `bootstrap` starts asking whether the subscription is live.

Both buttons — *Continue* and *Skip for now* — call `completePayment()`, which
does nothing but re-resolve the auth stage. The screen never navigates itself:
the router's redirect owns where a resolved stage lands, so a user whose org is
still under review correctly gets the pending screen rather than chats.

## Org is no longer a gate

`_resolveStageForRegisteredUser` used to return `needsOrg` for a user with no
orgs, which forced everyone through org selection. It now returns `signedIn`.

The org machinery is untouched and still reachable — create/join still exist,
and joining still comes back through the same resolver, which connects the
realtime socket at that point. The only consequence of having no org is that
`wsOrg(orgId)` has nothing to connect to, so a brand-new user has no live
socket until they join one. `needsOrg` survives as the offline fallback when
`/orgs/mine` can't be reached.

Because of that, **no org is now the normal state of the My Org tab**, not an
error. It used to render `Center(child: Text('No organization selected'))` — a
dead end that was unreachable while onboarding forced an org, and would have
been the first thing every new user saw. It now carries the same two doors the
old org-selection step offered: create, or join with an invite code. Covered by
`test/widgets/my_org_empty_test.dart`.

## Test

`test/widgets/payments_screen_test.dart` (6): both plans render with yearly
preselected, selection moves and stays single, Continue and Skip both end
onboarding, an active org signs in and connects the socket, an org under review
lands on pending.

The websocket client and push-token provider are stubbed there — signing in
with an active org opens a real socket, which never completes under test.
