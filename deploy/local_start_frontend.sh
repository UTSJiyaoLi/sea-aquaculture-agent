#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
FRONTEND_DIR="$ROOT_DIR/apps/web"
UI_PORT="${UI_PORT:-3007}"
LOCAL_PORT="${LOCAL_PORT:-8797}"
API_BASE="${VITE_API_BASE_URL:-http://127.0.0.1:${LOCAL_PORT}}"

if [ ! -f "$FRONTEND_DIR/package.json" ]; then
  echo "Frontend package.json not found at $FRONTEND_DIR"
  exit 1
fi

npm --prefix "$FRONTEND_DIR" install
VITE_API_BASE_URL="$API_BASE" npm --prefix "$FRONTEND_DIR" run dev -- --host 0.0.0.0 --port "$UI_PORT"
