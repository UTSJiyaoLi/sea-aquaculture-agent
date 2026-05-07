#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=${PROJECT_DIR:-/share/home/lijiyao/CCCC/sea-aquaculture-agent}
TMUX_SESSION=${TMUX_SESSION:-sea-aquaculture-agent-api}
BACKEND_PORT=${BACKEND_PORT:-8797}
LOG_DIR=${LOG_DIR:-$PROJECT_DIR/logs}
APPTAINER_IMAGE=${APPTAINER_IMAGE:-/share/home/lijiyao/CCCC/apptainer/inforhub.sif}
PYTHON_BIN=${PYTHON_BIN:-/usr/local/bin/python}

mkdir -p "$LOG_DIR"

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  tmux kill-session -t "$TMUX_SESSION"
fi

tmux new-session -d -s "$TMUX_SESSION" \
  "cd '$PROJECT_DIR' && apptainer exec --bind /share/home/lijiyao/CCCC:/share/home/lijiyao/CCCC '$APPTAINER_IMAGE' '$PYTHON_BIN' -m uvicorn backend.app:app --host 127.0.0.1 --port $BACKEND_PORT > '$LOG_DIR/backend.log' 2>&1"

echo "Started $TMUX_SESSION on 127.0.0.1:$BACKEND_PORT via Apptainer"
