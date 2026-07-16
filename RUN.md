# Doqto — Run Reference

All commands assume you're at the repo root (`HymnChat/`).

---

## One-shot dev startup

```bash
./scripts/dev.sh
```

Starts Postgres + Redis (docker), the FastAPI backend, and the Next.js admin panel, then tails all logs. Ctrl+C shuts everything down cleanly and preserves the Postgres volume.

| Flag | What it does |
|---|---|
| _(none)_ | infra + backend + admin (default) |
| `--flutter` | also runs Flutter on the booted iOS sim |
| `--backend-only` | just docker + uvicorn |
| `--admin-only` | just the admin (assumes backend is already up) |
| `--no-infra` | skip docker compose (Postgres/Redis already running) |

Env knobs:

- `FLUTTER=1 ./scripts/dev.sh` — same as `--flutter`
- `FLUTTER_DEVICE="iPhone 15" ./scripts/dev.sh --flutter` — pick a different simulator

If `dev.sh` was `kill -9`'d and left stragglers:

```bash
./scripts/stop.sh
```

---

## First-time setup

### Backend

```bash
cd doqto_backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# .env (copy and edit if needed)
cp .env.example .env

# Start infra + run migrations
docker compose up -d
alembic upgrade head
```

### Admin panel

```bash
cd doqto_admin
npm install
```

### Flutter app

```bash
cd doqto_app
flutter pub get

# First time only — iOS pods
cd ios && pod install && cd ..
```

---

## Manual per-service commands

Useful when you want each service in its own terminal for debugging.

### Infra (Postgres + Redis)

```bash
cd doqto_backend
docker compose up -d           # start
docker compose ps              # status
docker compose logs -f postgres
docker compose stop            # stop (preserves data)
docker compose down -v         # DESTROY data (super-admin, orgs)
```

### Backend (FastAPI)

```bash
cd doqto_backend
source venv/bin/activate
alembic upgrade head
uvicorn main:app --reload --port 8000
# Swagger → http://localhost:8000/docs
```

### Admin panel (Next.js)

```bash
cd doqto_admin
npm run dev
# http://localhost:3001
```

### Flutter app

```bash
cd doqto_app
flutter run -d "iPhone 17" \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=WS_BASE_URL=ws://localhost:8000
```

---

## Useful ad-hoc commands

```bash
# Postgres shell
psql postgresql://doqto:doqto@localhost:5432/doqto

# Redis shell
redis-cli -u redis://localhost:6379/0

# Autogenerate a new migration
cd doqto_backend && source venv/bin/activate
alembic revision --autogenerate -m "describe change"

# Clear Flutter build cache
cd doqto_app && flutter clean && flutter pub get

# List booted iOS simulators
xcrun simctl list devices booted

# Tail every service at once
tail -F logs/*.log
```

---

## Ports & URLs

| Service | Port | URL |
|---|---|---|
| Postgres | 5432 | `postgresql://doqto:doqto@localhost:5432/doqto` |
| Redis | 6379 | `redis://localhost:6379/0` |
| Backend API | 8000 | http://localhost:8000 |
| Backend Swagger | 8000 | http://localhost:8000/docs |
| Admin panel | 3001 | http://localhost:3001 |
| Landing site | 3000 | http://localhost:3000 |

---

## Default dev credentials

| What | Value |
|---|---|
| Super-admin email | `admin@doqto.app` |
| Super-admin password | `ChangeMe123!` |
| Super-admin phone | `+15555550100` |
| Super-admin NPI | `0000000001` |
| Dev-only OTP (any phone) | `777777` |

Sourced from `doqto_backend/.env`. Rotate there and re-run alembic to change.

---

## Troubleshooting

**Port already in use (5432 / 6379 / 8000 / 3001)**
```bash
lsof -iTCP:8000 -sTCP:LISTEN       # find PID
./scripts/stop.sh                   # or: kill -9 <pid>
```

**Flutter: "Lost connection to device"**
```bash
./scripts/stop.sh
xcrun simctl shutdown all
# relaunch sim, then re-run dev.sh --flutter
```

**Backend fails migrations / schema drift**
```bash
cd doqto_backend
docker compose down -v            # wipes DB (destroys super-admin + orgs)
docker compose up -d
alembic upgrade head               # seeds super-admin again
```

**Admin login 401 with correct creds**
Backend hasn't finished booting. Re-check `curl -sf http://localhost:8000/docs` before submitting the login form.

**Docker not running**
Open Docker Desktop, wait for the whale icon to go steady, then retry.
