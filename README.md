# Doqto

A HIPAA-oriented, doctor-to-doctor messaging platform. Verified physicians join or create an organization, then exchange text and voice notes (auto-transcribed via AWS Transcribe Medical) with colleagues across direct and group chats.

Active branch: **`revamp`**. The pre-wipe HymnChat codebase is preserved at tag/branch `backup/pre-wipe-2026-05-03`.

---

## Repo layout

| Path | What it is |
|---|---|
| [`doqto_backend/`](doqto_backend/README.md) | FastAPI service (Python 3.13) — auth, orgs, messaging, WS, admin |
| [`doqto_admin/`](doqto_admin/README.md) | Next.js 16 admin panel — super-admin org approvals |
| [`doqto_app/`](doqto_app/README.md) | Flutter app (iOS + Android) |
| `landing/` | Marketing site (Next.js) |
| `docs/` | `design.md` (tokens), `enums.md` (cross-stack wire values), business docs |
| `stitch_doqto_medical_messenger/` | UI ground truth — 17 screens (HTML + PNG) + DESIGN.md |
| `scripts/` | `dev.sh`, `stop.sh`, `check_enum_parity.py` |

---

## Stack

- **Mobile:** Flutter 3.38, Riverpod, GoRouter, Dio, Freezed, flutter_secure_storage
- **Backend:** FastAPI 0.115, SQLAlchemy 2 async, PostgreSQL 15, Redis 7, Alembic
- **Admin:** Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS v4
- **Infra:** AWS S3 + Transcribe Medical + SNS (HIPAA BAA) — stubbed with fakes locally

---

## Quick start

```bash
./scripts/dev.sh
```

Boots Postgres + Redis (docker), the FastAPI backend on `:8000`, and the admin panel on `:3001`. Ctrl+C shuts everything down cleanly.

Full command reference and first-time setup → [**RUN.md**](RUN.md).

| | URL |
|---|---|
| Backend (Swagger) | http://localhost:8000/docs |
| Admin panel | http://localhost:3001 |
| Landing | http://localhost:3000 |

Default super-admin: `admin@doqto.app` / `ChangeMe123!` — see [RUN.md](RUN.md#default-dev-credentials).

---

## Architectural principle — Single Source of Truth

Every color, enum wire value, Redis key, and API path lives in exactly one place and propagates everywhere. See [`docs/design.md`](docs/design.md) for the design tokens and [`docs/enums.md`](docs/enums.md) for the cross-stack enum contract. The parity script at `scripts/check_enum_parity.py` fails the build if Python and Dart enums drift.

---

## Deeper docs

- [`doqto_backend/README.md`](doqto_backend/README.md) — backend architecture, migrations, services
- [`doqto_admin/README.md`](doqto_admin/README.md) — admin panel auth flow
- [`doqto_app/README.md`](doqto_app/README.md) — Flutter app layout
- [`docs/design.md`](docs/design.md) — design tokens (colors, type, spacing, motion)
- [`docs/enums.md`](docs/enums.md) — wire-value contract
- [`RUN.md`](RUN.md) — all run + troubleshooting commands
