# Message edit and delete — design

Date: 2026-09-05. Branch: `revamp`.

## Goal

Text messages can be edited by their sender for 5 minutes after sending, with
the full edit history visible to every conversation member. Any message can be
deleted by its sender for 3 minutes after sending; both sides then see a
"This message was deleted" tombstone, WhatsApp style.

## Rules

| Action | Who | Window (from `created_at`, server clock) | Types |
|--------|-----|------------------------------------------|-------|
| Edit   | sender only | 5 minutes | `text` only |
| Delete | sender only | 3 minutes | any non-system type |

- Windows are enforced on the server. The client hides the actions once the
  window has passed but the server decision is final (409 `edit_window_closed`
  / `delete_window_closed`).
- Editing a deleted message is rejected (409 `message_deleted`).
- Edit content follows the same validation as a send (1–5000 chars). Editing to
  identical content is a no-op that returns the message unchanged.
- A deleted message keeps its row and `seq` (gapless catch-up), loses its
  content, attachment key, transcript, and every edit-history row. Its S3 object
  is deleted. This is crypto-shred on demand and matches the existing purge.
- Edit history is transparent: any conversation member can fetch it. Each entry
  is a previous version with the time that version was replaced.

## Data model

`messages` gains two nullable timestamps:

- `edited_at` — set on each edit. Non-null means "show the Edited label".
- `deleted_at` — set on user delete. Distinct from `is_deleted`, which means
  "expired or purged, hide from lists". A user-deleted message stays in lists.

New table `message_edits` (one row per superseded version):

| column | type | note |
|--------|------|------|
| id | uuid pk | |
| message_id | uuid fk messages.id ON DELETE CASCADE, indexed | |
| content_encrypted | bytea not null | the previous content, PHI, encrypted like bodies |
| replaced_at | timestamptz not null default now() | when this version stopped being current |

Migration `0019_message_edit_delete`.

## API

All under `/api/v1/messages`, sender-only, member check as today.

- `PATCH /{message_id}` body `{content}` → `MessageOut`. Appends the current
  content to `message_edits`, replaces the body, stamps `edited_at`, audit
  `message_edited`, broadcasts `message_edited` with the full `MessageOut`.
- `DELETE /{message_id}` → `MessageOut`. Nulls content, transcript, s3_key,
  deletes `message_edits` rows and the S3 object, stamps `deleted_at`, audit
  `message_deleted`, broadcasts `message_deleted` with the full `MessageOut`.
- `GET /{message_id}/edits` → `list[MessageEditOut]` `{content, replaced_at}`
  oldest first. Any member. Empty list for a deleted message. Audit
  `conversation_accessed` is not repeated; the thread was already opened.

`MessageOut` gains `edited_at: datetime | null` and `deleted_at: datetime | null`.

Chat-list preview for a deleted last message shows "This message was deleted";
for an edited message the current text.

## WebSocket

Two new server events, both carrying the full `MessageOut` so clients replace
the row in place: `message_edited`, `message_deleted`. Fan out to all members.
Push notifications are not sent for edits or deletes.

## Client (Flutter)

- `Message` gains `editedAt`, `deletedAt`, serialised in `fromJson`/`toJson`,
  carried through `copyWith`. Helpers `canEdit(now)` / `canDelete(now)` compute
  the window locally for menu visibility only.
- `ChatRepository` gains `editMessage`, `deleteMessage`, `messageEdits`.
- `MessagesNotifier` handles `messageEdited` / `messageDeleted` by replacing the
  row by id (also recaches), and exposes `edit(id, text)` / `delete(id)` which
  apply the server response the same way.
- Long-press on your own sent bubble opens a bottom sheet: **Edit** (text, inside
  5 min), **Delete** (inside 3 min). Outside the windows the sheet shows only
  what is still allowed; nothing allowed → no sheet. Failed or pending bubbles
  keep the existing retry/discard sheet.
- Edit flow: the composer switches to edit mode with the current text, a
  dismissible "Editing message" strip above it, send icon becomes a check.
  Sending calls `edit`. Composer keeps `onTapOutside` unfocus.
- Bubble rendering: deleted → italic muted "This message was deleted" with a
  block icon, no ticks, no long-press menu, same alignment. Edited → small
  "Edited" label next to the time; tapping the label (either side) opens a
  bottom sheet listing every previous version with its timestamp, newest first,
  fetched from `GET /edits`.
- Media bubbles (image, file, voice) get the same long-press Delete option and
  the same tombstone when deleted.

## Errors

| server detail | client |
|---------------|--------|
| `edit_window_closed` / `delete_window_closed` | snackbar "Too late to edit/delete this message" and refresh the row |
| `not_message_sender` (403) | snackbar generic |
| `message_deleted` | snackbar "Message was deleted", refresh |
| `message_not_editable` (non-text) | not reachable from UI |

## Testing

Backend `tests/test_message_edit_delete.py`:
1. Edit within window: content replaced, `edited_at` set, history has one entry
   with the old text, WS payload carries the event.
2. Edit after 5 min (row `created_at` backdated): 409.
3. Non-sender edit: 403. Non-text edit: 409.
4. Delete within window: `deleted_at` set, content/s3_key null, history empty,
   message still listed with `seq`, chat-list preview is the tombstone text.
5. Delete after 3 min: 409. Edit after delete: 409.
6. Member can read history; non-member 403.

Flutter: model round-trip and window helpers in `test/message_edit_delete_test.dart`;
widget test that a deleted message renders the tombstone and an edited message
shows the label. `flutter analyze lib test` and `flutter test` clean.

Verification: backend pytest suite against local docker Postgres/Redis; the
app run on a simulator with two accounts to confirm both sides update live.

## Out of scope

Editing media captions, editing group system messages, admin deletion of others'
messages, un-delete.
