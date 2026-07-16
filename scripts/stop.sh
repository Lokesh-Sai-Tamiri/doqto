#!/usr/bin/env bash
# Belt-and-suspenders cleanup when ./scripts/dev.sh was force-killed.
set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[stop] killing uvicorn / next / flutter processes"
pkill -f "uvicorn main:app"        2>/dev/null || true
pkill -f "next dev"                2>/dev/null || true
pkill -f "flutter.*doqto"        2>/dev/null || true
pkill -f "dartaotruntime"          2>/dev/null || true
pkill -f "frontend_server_aot"     2>/dev/null || true

echo "[stop] stopping docker compose (preserves volumes)"
(cd "$REPO_ROOT/doqto_backend" && docker compose stop) 2>/dev/null || true

echo "[stop] done"
