#!/usr/bin/env bash
set -euo pipefail

TMUX_SESSION=${TMUX_SESSION:-sea-aquaculture-agent-api}

if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  tmux kill-session -t "$TMUX_SESSION"
  echo "Stopped $TMUX_SESSION"
else
  echo "Session $TMUX_SESSION not found"
fi
