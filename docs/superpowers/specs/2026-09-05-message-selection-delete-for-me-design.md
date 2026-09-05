# Message selection, Delete for me / Delete for everyone (WhatsApp clone)

Extends `2026-09-05-message-edit-delete-design.md`.

## WhatsApp behaviour cloned

| Action | Rule |
|---|---|
| Long-press any bubble (mine or theirs, live or tombstone) | enters selection mode; row tints; app bar becomes `X  N  [✎] [🗑]` |
| Tap while selecting | toggles that row; the bubble's own taps are swallowed |
| Back / X | leaves selection mode |
| ✎ (Edit) | shown only when exactly ONE message is selected, it is mine, text, sent < 5 min ago |
| 🗑 → dialog | "Delete message?" / "Delete N messages?" |
| "Delete for me" | always offered. Hides the messages for me only, any age, mine or theirs, tombstones included |
| "Delete for everyone" | offered only when EVERY selected message is mine and sent < 3 min ago. Tombstones both sides (existing flow) |
| Mixed (mine + theirs) or any > 3 min | only "Delete for me" |
| System messages | not selectable |

Source: WhatsApp help + third-party writeups; "Delete for everyone" is sender-only and time-boxed, mixed selections fall back to "Delete for me".

## Backend

- `message_hides(message_id PK, user_id PK, hidden_at)` — migration `0020_message_hides`.
- `POST /api/v1/messages/hide {message_ids: [≤100]}` → hides those the caller can see (member of the conversation). Idempotent; unknown/foreign ids are ignored.
- `list_messages` and the chat-list preview (`latest_per_conversation`) exclude rows hidden for the caller.
- No WS event: nothing changes for anyone else.

## App

- `MessagesNotifier.hide(ids)` → POST, drop rows locally, recache.
- `ChatThreadScreen`: `_selected` set; `_selectable` row wrapper; `_selectionBar`; `_deleteSelected` dialog; `PopScope` so back exits selection. Old long-press bottom sheet removed.
- Keys for tests: `select-close`, `select-edit`, `select-delete`, `delete-for-me`, `delete-for-everyone`.

## Verification

- Backend: `tests/test_message_edit_delete.py` (+2: per-user hide incl. preview & idempotency; outsider ignored).
- App: `flutter analyze` + `flutter test`; `integration_test/message_edit_delete_test.dart` on simulator covers select → edit → history → delete for everyone → mixed/old selection shows only delete-for-me → row disappears.
