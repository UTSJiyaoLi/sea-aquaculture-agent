#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
  conda activate rag_task
else
  echo "conda.sh not found; activate rag_task manually before running this script."
fi

cd "$ROOT_DIR/apps/web"
npm install
NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL:-http://127.0.0.1:8797} npm run dev -- --port 3007
