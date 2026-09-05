# Message Edit/Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sender can edit a text message for 5 minutes (history visible to all members) and delete any message for 3 minutes (tombstone on both sides).

**Architecture:** Two timestamps on `messages` plus a `message_edits` history table; three sender-gated endpoints under `/api/v1/messages`; two WS events carrying the full `MessageOut`; the Flutter thread replaces rows in place and renders tombstone/edited label.

**Tech Stack:** FastAPI + SQLAlchemy async + Alembic (backend), Flutter/Riverpod (client).

**Spec:** `docs/superpowers/specs/2026-09-05-message-edit-delete-design.md`

## Global Constraints

- Edit window 5 min, delete window 3 min, measured from `created_at` on the server.
- Edit only `text`; delete any non-system type.
- Deleted message keeps row + seq; content, transcript, s3_key, edit rows, S3 object removed.
- Every Flutter text input has `onTapOutside` unfocus (CLAUDE.md).
- `flutter analyze lib test` and `flutter test` clean before claiming done.

---

### Task 1: Backend schema + service

**Files:**
- Modify: `doqto_backend/app/models/message.py` (add `edited_at`, `deleted_at`, `MessageEdit`)
- Modify: `doqto_backend/app/models/__init__.py`, `app/db/tables.py` (`MESSAGE_EDITS`)
- Create: `doqto_backend/alembic/versions/0019_message_edit_delete.py`
- Modify: `app/core/constants.py` (`MESSAGE_EDIT_WINDOW_SEC=300`, `MESSAGE_DELETE_WINDOW_SEC=180`)
- Modify: `app/core/enums.py` (`AuditAction.MESSAGE_EDITED/MESSAGE_DELETED`, `WsEventServer.MESSAGE_EDITED/MESSAGE_DELETED`)
- Modify: `app/schemas/message.py` (`MessageOut.edited_at/deleted_at`, `MessageEditIn`, `MessageEditOut`)
- Modify: `app/services/message_service.py` (`edit_message`, `delete_message`, `list_edits`, `to_out`)
- Test: `doqto_backend/tests/test_message_edit_delete.py`

**Interfaces produced:**
- `MessageService.edit_message(*, message_id, user_id, content, db) -> Message` raises `MessageError("not_message_sender"|"message_deleted"|"message_not_editable"|"edit_window_closed"|"message_not_found")`
- `MessageService.delete_message(*, message_id, user_id, db) -> tuple[Message, str | None]` (s3 key to delete) raises `MessageError("not_message_sender"|"message_deleted"|"delete_window_closed"|"message_not_found")`
- `MessageService.list_edits(*, message_id, db) -> list[MessageEdit]`

- [ ] Write failing tests (service-level: edit within/after window, non-sender, non-text, delete within/after, edit after delete).
- [ ] Run `venv/bin/pytest tests/test_message_edit_delete.py -q` → fails (attribute errors).
- [ ] Implement model, migration, constants, enums, schema, service.
- [ ] Tests pass. Commit.

### Task 2: Backend API + WS + preview

**Files:**
- Modify: `app/core/routes.py` (`MESSAGES_EDIT="/{message_id}"`, `MESSAGES_DELETE="/{message_id}"`, `MESSAGES_EDITS="/{message_id}/edits"`)
- Modify: `app/api/v1/messages.py` (three routes)
- Modify: `app/api/v1/conversations.py::_preview_for` (tombstone preview)
- Test: extend `tests/test_message_edit_delete.py` with HTTP tests (200/403/409, WS payload via monkeypatched `ws_manager.publish_to_users`, deleted message still listed, preview text).

- [ ] Write failing HTTP tests → run → implement → pass → commit.

### Task 3: Flutter model + repository + state

**Files:**
- Modify: `doqto_app/lib/data/models/message.dart` (`editedAt`, `deletedAt`, `canEdit`, `canDelete`, `copyWith`)
- Modify: `lib/core/enums/app_enums.dart` (`messageEdited`, `messageDeleted`)
- Modify: `lib/core/constants/api_routes.dart` (`message(id)`, `messageEdits(id)`)
- Modify: `lib/data/repositories/chat_repository.dart` (`editMessage`, `deleteMessage`, `messageEdits`)
- Create: `lib/data/models/message_edit.dart`
- Modify: `lib/state/chat_state.dart` (`_replace`, WS cases, `edit`, `delete`)
- Test: `test/message_edit_delete_test.dart` (json round trip, window helpers)

- [ ] Write failing test → `flutter test test/message_edit_delete_test.dart` → implement → pass → commit.

### Task 4: Flutter UI

**Files:**
- Modify: `lib/ui/widgets/message_bubble.dart` (`deleted`, `edited`, `onEditedTap`)
- Modify: `lib/ui/screens/chat/chat_thread_screen.dart` (long-press sheet, edit mode composer, history sheet, error snackbars)
- Modify: `lib/core/constants/strings.dart` (copy)
- Test: `test/widgets/message_bubble_edit_delete_test.dart`

- [ ] Widget test → implement → `flutter analyze lib test` + `flutter test` clean → commit.

### Task 5: Verification

- [ ] Full backend suite `venv/bin/pytest -q`.
- [ ] Apply migration locally (`alembic upgrade head`) against docker Postgres.
- [ ] Simulator run of the thread screen; report results.
