#!/usr/bin/env bash
# Doqto one-shot dev startup.
#
#   ./scripts/dev.sh                → infra + backend + admin (default)
#   ./scripts/dev.sh --flutter      → also runs flutter on the booted iOS sim
#   ./scripts/dev.sh --backend-only → just docker + uvicorn
#   ./scripts/dev.sh --admin-only   → just admin (assumes backend is up elsewhere)
#   ./scripts/dev.sh --no-infra     → skip docker compose (db/redis already running)

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BACKEND_DIR="$REPO_ROOT/doqto_backend"
ADMIN_DIR="$REPO_ROOT/doqto_admin"
APP_DIR="$REPO_ROOT/doqto_app"
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"

RUN_BACKEND=1
RUN_ADMIN=1
RUN_INFRA=1
RUN_FLUTTER=${FLUTTER:-0}
FLUTTER_DEVICE="${FLUTTER_DEVICE:-iPhone 17}"

for arg in "$@"; do
    case "$arg" in
        --flutter)      RUN_FLUTTER=1 ;;
        --backend-only) RUN_ADMIN=0; RUN_FLUTTER=0 ;;
        --admin-only)   RUN_BACKEND=0; RUN_INFRA=0; RUN_FLUTTER=0 ;;
        --no-infra)     RUN_INFRA=0 ;;
        -h|--help)
            sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

BLUE=$'\e[34m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; DIM=$'\e[2m'; RESET=$'\e[0m'
log()  { printf '%s[dev]%s %s\n' "$BLUE"  "$RESET" "$*"; }
ok()   { printf '%s[ ok]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s[err]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

BACKEND_PID=""; ADMIN_PID=""; FLUTTER_PID=""; TAIL_PID=""

cleanup() {
    echo
    log "shutting down…"
    [[ -n "$TAIL_PID"    ]] && kill "$TAIL_PID"    2>/dev/null || true
    [[ -n "$FLUTTER_PID" ]] && kill "$FLUTTER_PID" 2>/dev/null || true
    [[ -n "$ADMIN_PID"   ]] && kill "$ADMIN_PID"   2>/dev/null || true
    [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" 2>/dev/null || true
    # give them a beat to exit cleanly, then force
    sleep 1
    pkill -f "uvicorn main:app" 2>/dev/null || true
    pkill -f "next dev"         2>/dev/null || true
    if [[ "$RUN_INFRA" -eq 1 ]]; then
        (cd "$BACKEND_DIR" && docker compose stop >/dev/null 2>&1) || true
    fi
    ok "bye"
}
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------
log "pre-flight checks"

if [[ "$RUN_INFRA" -eq 1 ]]; then
    docker info >/dev/null 2>&1 || die "docker is not running (open Docker Desktop)"
fi
if [[ "$RUN_BACKEND" -eq 1 ]]; then
    [[ -d "$BACKEND_DIR/venv" ]] || die "missing $BACKEND_DIR/venv — run: python3 -m venv venv && pip install -r requirements.txt"
fi
if [[ "$RUN_ADMIN" -eq 1 ]]; then
    [[ -d "$ADMIN_DIR/node_modules" ]] || die "missing $ADMIN_DIR/node_modules — run: cd doqto_admin && npm install"
fi
if [[ "$RUN_FLUTTER" -eq 1 ]]; then
    command -v flutter >/dev/null || die "flutter not on PATH"
fi

# -----------------------------------------------------------------------------
# Infra (Postgres + Redis)
# -----------------------------------------------------------------------------
if [[ "$RUN_INFRA" -eq 1 ]]; then
    log "starting Postgres + Redis via docker compose"
    (cd "$BACKEND_DIR" && docker compose up -d) >/dev/null

    # wait for health
    for svc in postgres redis; do
        printf "     waiting for %s " "$svc"
        for i in {1..30}; do
            state=$(cd "$BACKEND_DIR" && docker compose ps --format '{{.Service}} {{.Health}}' 2>/dev/null | awk -v s="$svc" '$1==s {print $2}')
            [[ "$state" == "healthy" ]] && { echo " ${GREEN}ok${RESET}"; break; }
            printf "."
            sleep 1
            [[ $i -eq 30 ]] && { echo; die "$svc did not become healthy in 30s"; }
        done
    done
fi

# -----------------------------------------------------------------------------
# Backend (uvicorn)
# -----------------------------------------------------------------------------
wait_http() {
    local url="$1" name="$2"
    printf "     waiting for %s " "$name"
    for i in {1..60}; do
        if curl -sf -o /dev/null "$url"; then echo " ${GREEN}ok${RESET}"; return 0; fi
        printf "."
        sleep 1
    done
    echo; die "$name did not come up (see logs/)"
}

if [[ "$RUN_BACKEND" -eq 1 ]]; then
    log "starting backend (uvicorn) → logs/backend.log"
    (
        cd "$BACKEND_DIR"
        # Explicit: the code default is the fail-safe "production".
        export ENVIRONMENT=local
        # shellcheck source=/dev/null
        source venv/bin/activate
        alembic upgrade head >/dev/null 2>&1 || true
        exec uvicorn main:app --reload --port 8000
    ) >"$LOG_DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    wait_http "http://localhost:8000/docs" "backend"
fi

# -----------------------------------------------------------------------------
# Admin (next dev)
# -----------------------------------------------------------------------------
if [[ "$RUN_ADMIN" -eq 1 ]]; then
    log "starting admin (next dev) → logs/admin.log"
    (cd "$ADMIN_DIR" && exec npm run dev) >"$LOG_DIR/admin.log" 2>&1 &
    ADMIN_PID=$!
    wait_http "http://localhost:3001/login" "admin"
fi

# -----------------------------------------------------------------------------
# Flutter (opt-in)
# -----------------------------------------------------------------------------
if [[ "$RUN_FLUTTER" -eq 1 ]]; then
    # Resolve a concrete UDID — there can be multiple "iPhone 17" entries across
    # iOS runtimes. Prefer any already-booted sim; otherwise take the last entry
    # with the given name (typically the newest runtime).
    SIM_UDID=$(xcrun simctl list devices booted 2>/dev/null | awk -v name="$FLUTTER_DEVICE" '
        $0 ~ "^[[:space:]]*" name " \\(" { match($0, /[A-F0-9-]{36}/); print substr($0, RSTART, RLENGTH); exit }
    ')
    if [[ -z "$SIM_UDID" ]]; then
        SIM_UDID=$(xcrun simctl list devices available 2>/dev/null | awk -v name="$FLUTTER_DEVICE" '
            $0 ~ "^[[:space:]]*" name " \\(" { match($0, /[A-F0-9-]{36}/); udid = substr($0, RSTART, RLENGTH) }
            END { print udid }
        ')
    fi
    [[ -z "$SIM_UDID" ]] && die "simulator '$FLUTTER_DEVICE' not found — list with: xcrun simctl list devices available"

    if ! xcrun simctl list devices booted 2>/dev/null | grep -q "$SIM_UDID"; then
        log "booting simulator '$FLUTTER_DEVICE' ($SIM_UDID)"
        xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
        open -a Simulator >/dev/null 2>&1 || true
        printf "     waiting for simulator "
        for i in {1..60}; do
            if xcrun simctl list devices booted 2>/dev/null | grep -q "$SIM_UDID"; then
                echo " ${GREEN}ok${RESET}"; break
            fi
            printf "."; sleep 1
            [[ $i -eq 60 ]] && { echo; die "simulator did not boot in 60s"; }
        done
    else
        ok "simulator already booted ($SIM_UDID)"
    fi

    log "starting flutter on '$FLUTTER_DEVICE' → logs/flutter.log"
    (
        cd "$APP_DIR"
        exec flutter run -d "$SIM_UDID" \
            --dart-define=API_BASE_URL=http://localhost:8000 \
            --dart-define=WS_BASE_URL=ws://localhost:8000
    ) </dev/null >"$LOG_DIR/flutter.log" 2>&1 &
    FLUTTER_PID=$!
fi

# -----------------------------------------------------------------------------
# Ready banner + log stream
# -----------------------------------------------------------------------------
echo
ok "doqto is up"
[[ "$RUN_BACKEND" -eq 1 ]] && printf "     %sbackend%s  http://localhost:8000/docs\n" "$BLUE" "$RESET"
[[ "$RUN_ADMIN"   -eq 1 ]] && printf "     %sadmin%s    http://localhost:3001\n"      "$BLUE" "$RESET"
[[ "$RUN_FLUTTER" -eq 1 ]] && printf "     %sflutter%s  see logs/flutter.log\n"        "$BLUE" "$RESET"
echo
printf "%sCtrl+C to stop everything%s\n\n" "$DIM" "$RESET"

# Stream logs with a [service] prefix.
FILES=()
[[ "$RUN_BACKEND" -eq 1 ]] && FILES+=("$LOG_DIR/backend.log")
[[ "$RUN_ADMIN"   -eq 1 ]] && FILES+=("$LOG_DIR/admin.log")
[[ "$RUN_FLUTTER" -eq 1 ]] && FILES+=("$LOG_DIR/flutter.log")

if [[ ${#FILES[@]} -gt 0 ]]; then
    # ensure the files exist so tail doesn't error on cold start
    for f in "${FILES[@]}"; do : > "$f"; done
    tail -n 0 -F "${FILES[@]}" 2>/dev/null | awk '
        /^==> .* <==$/ {
            name = $0
            sub(/^==> .*\//, "", name); sub(/\.log <==$/, "", name)
            next
        }
        { printf "[%s] %s\n", name, $0; fflush() }
    ' &
    TAIL_PID=$!
fi

# Wait on the primary long-running services. If any exits, cleanup() fires.
# (Polling loop — macOS ships bash 3.2 which has no `wait -n`.)
while true; do
    for pid in "$BACKEND_PID" "$ADMIN_PID" "$FLUTTER_PID"; do
        if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
            warn "service pid $pid exited — shutting down"
            exit 1
        fi
    done
    sleep 2
done
