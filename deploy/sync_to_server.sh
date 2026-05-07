#!/usr/bin/env bash
set -euo pipefail

LOCAL_ROOT=${LOCAL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
JUMP_HOST=${JUMP_HOST:-lijiyao}
REMOTE_HOST=${REMOTE_HOST:-gpu6000}
REMOTE_ROOT=${REMOTE_ROOT:-/share/home/lijiyao/CCCC/sea-aquaculture-agent}

ssh -J "$JUMP_HOST" "$REMOTE_HOST" "mkdir -p '$REMOTE_ROOT'"

for item in backend apps deploy docs Data model_tools scripts .env.example AGENTS.md README.md requirements.txt pyproject.toml Patent_fishi.py MFPCA_paper.R; do
  if [ -e "$LOCAL_ROOT/$item" ]; then
    scp -r -J "$JUMP_HOST" "$LOCAL_ROOT/$item" "$REMOTE_HOST:$REMOTE_ROOT/"
  fi
done
