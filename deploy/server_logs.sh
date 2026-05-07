#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=${PROJECT_DIR:-/share/home/lijiyao/CCCC/sea-aquaculture-agent}
LOG_DIR=${LOG_DIR:-$PROJECT_DIR/logs}
tail -n 200 "$LOG_DIR/backend.log"
