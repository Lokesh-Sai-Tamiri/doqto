# Dox2Dox — Cross-Stack Enum Contract

> Single source of truth for every enum shared between Flutter and FastAPI.
> Wire values (right column) are the JSON representation — these MUST match exactly on both sides.
> A CI gate (`scripts/check_enum_parity.py`) compares this file to `app/core/enums.py` (Python) and `lib/core/enums/*.dart` (Dart) on every build.

## Rules

1. **Wire values are `snake_case` lowercase strings.** No camelCase on the wire.
2. **Dart enum names are `camelCase`** (Dart idiom), mapped to wire via `@JsonValue('...')`.
3. **Python enum values ARE the wire strings** (use `StrEnum`). Member names can be UPPER_SNAKE.
4. **Adding a value:** update this file → update `enums.py` → update `enums/*.dart` → parity check passes.
5. **Removing a value:** add a migration — never silently drop. Mark deprecated here first.
6. **Reordering:** fine for humans, irrelevant for wire.

---

## UserRole

| Wire value | Meaning |
|---|---|
| `doctor` | Standard doctor account |
| `super_admin` | Platform operator who verifies orgs |

## OrgStatus

| Wire value | Meaning |
|---|---|
| `pending` | Awaiting super-admin verification |
| `active` | Verified and operational |
| `suspended` | Disabled by super-admin |

## OrgRole

| Wire value | Meaning |
|---|---|
| `admin` | Org admin (creator by default) |
| `doctor` | Regular member |

## PracticeType

| Wire value | Meaning |
|---|---|
| `independent` | Independent practice |
| `specialty_group` | Multi-doctor specialty group |
| `community_hospital` | Community hospital |

## ConversationType

| Wire value | Meaning |
|---|---|
| `direct` | 1:1 between two doctors |
| `group` | 3+ members, has name |

## MessageType

| Wire value | Meaning |
|---|---|
| `text` | Plain text (encrypted at rest) |
| `voice_note` | Audio + auto-transcript |
| `image` | Image attachment |
| `file` | Generic file attachment |
| `system` | System event (joined/left/removed) |

## TranscriptStatus

| Wire value | Meaning |
|---|---|
| `none` | Not a voice note |
| `pending` | Transcribe job running |
| `completed` | Transcript available |
| `failed` | Transcribe job errored |

## PresenceStatus

| Wire value | Meaning |
|---|---|
| `online` | Active in last 5 min |
| `away` | Inactive 5–30 min |
| `offline` | Inactive 30+ min |

## DisappearAfter

Stored as raw integer seconds in DB (`conversations.disappear_after_sec`), but Flutter selects via enum:

| Wire value (int seconds) | Enum member | Meaning |
|---|---|---|
| `null` | `off` | Disappearing disabled |
| `86400` | `day` | 24 hours |
| `604800` | `week` | 7 days |
| `2592000` | `month` | 30 days |
| `7776000` | `quarter` | 90 days |

## WsEventServer (server → client)

| Wire value | Payload fields |
|---|---|
| `new_message` | `message_id, conversation_id, sender_id, type, content, created_at` |
| `transcript_ready` | `message_id, transcript` |
| `message_delivered` | `message_id, user_id, delivered_at` |
| `message_read` | `message_id, user_id, read_at` |
| `presence_update` | `user_id, status` |
| `member_added` | `conversation_id, user_id, user_name` |
| `member_removed` | `conversation_id, user_id` |
| `system_message` | `conversation_id, text` |
| `typing_start` | `conversation_id, user_id` |
| `typing_stop` | `conversation_id, user_id` |

## WsEventClient (client → server)

| Wire value | Payload |
|---|---|
| `heartbeat` | `{}` — sent every 60s |
| `typing_start` | `conversation_id` |
| `typing_stop` | `conversation_id` |

## JwtTokenType

| Wire value | Meaning |
|---|---|
| `access` | Short-lived (1h) |
| `refresh` | Long-lived (7d) |

## AuditAction

| Wire value | Meaning |
|---|---|
| `login` | User authenticated successfully |
| `logout` | Session invalidated |
| `register` | New user completed profile |
| `otp_requested` | OTP SMS requested |
| `otp_verified` | OTP successfully verified |
| `org_created` | Organization created |
| `org_joined` | User joined an organization |
| `org_verified` | Super-admin verified an org |
| `member_removed` | Admin removed a doctor |
| `conversation_created` | Direct/group created |
| `group_member_added` | Doctor added to group |
| `group_member_left` | Doctor left group |
| `group_member_removed` | Doctor removed by creator |
| `message_sent` | Message persisted |
| `message_read` | Message marked read |
| `file_uploaded` | File/voice attachment uploaded |
| `file_accessed` | Presigned URL issued |

## TranscribeSpecialty (AWS Transcribe Medical)

These map to AWS API values — do NOT lowercase for wire, AWS requires UPPERCASE.

| Wire value | Meaning |
|---|---|
| `PRIMARYCARE` | Default |
| `CARDIOLOGY` | Cardiology specialty |
| `RADIOLOGY` | Radiology specialty |
| `NEUROLOGY` | Neurology specialty |
| `UROLOGY` | Urology specialty |

## AvatarColor (Flutter-only — no wire)

Index-keyed color cycle from `design.md §2`. Not serialized over the wire; derived deterministically from user index.

| Index | Name | Hex |
|---|---|---|
| 0 | blue | `#1A56DB` |
| 1 | teal | `#0ABFAD` |
| 2 | purple | `#7C3AED` |
| 3 | darkBlue | `#0F3499` |
| 4 | amber | `#F59E0B` |
