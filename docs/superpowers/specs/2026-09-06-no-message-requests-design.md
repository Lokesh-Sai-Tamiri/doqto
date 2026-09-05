# Direct chat: colleagues and connections only (message-request tier removed)

## Rule

A direct conversation may be created and messaged only when the two users
**share an organization** or are **first-degree connections**. Everyone else
is `403 not_connected` — on create and on every send, so a removed connection
or a block freezes the thread immediately. Blocks still surface as
`user_unavailable` / `not_reachable` (silence rule).

Consequences:
- No message-request tier: no `pending_request`/`declined` state, no
  accept/decline endpoints, no one-message guard, no spam gate, no request
  push or WS events, no daily quota.
- DM privacy policy (`dm_policy`) no longer affects reachability.
- Accepting a connection request unlocks chat instantly; the thread has no
  "not connected" banner because the server would not have opened it.

## Backend

- `permissions._direct_decision`: blocked → self → colleague(open) →
  connection(open) → `not_connected`. `can_message` = same table.
- `conversations.py`: create returns 403 on denied; send re-checks; list is
  the full membership list; `?filter=requests` → `[]` for ≤ build 17 clients.
- Migration `0021_no_message_requests`: every conversation `access='open'`.
- Removed: request accept/decline routes, `_reject_media_pre_accept`,
  `notify_message_request`, request constants, `tests/test_m4_request_tier.py`.

## App

- Messages screen: no Focused/Requests segmented tabs; search + list only.
- Thread: composer always shown; `RequestComposerBar`, `RequestCard`, the
  not-connected banner, accept/decline/block-from-thread, `requestsProvider`
  and request WS handlers are gone. A 403 `not_connected` on send shows
  "Connect with this doctor to message them."
- Profile: the button always reads "Message" (hidden when `can_message` is
  denied).

## Verified

- Backend suite (169) incl. new denial/compat tests.
- Live local API: stranger 403 → invite → accept → both directions 200 within
  the same second; colleagues 200; legacy filter empty.
- `flutter analyze` + `flutter test` clean; on-device integration test on the
  iPhone 16 Pro simulator; screenshot of the tab-less Messages screen.
