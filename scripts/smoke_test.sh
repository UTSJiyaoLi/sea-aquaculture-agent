#!/usr/bin/env bash
set -euo pipefail

API_BASE=${API_BASE:-http://127.0.0.1:8797}

curl -fsS "$API_BASE/health" | python -m json.tool
curl -fsS "$API_BASE/api/batches" | python -m json.tool
curl -fsS "$API_BASE/api/batches/BATCH_A/profile" | python -m json.tool
curl -fsS -X POST "$API_BASE/api/production/plan" \
  -H 'Content-Type: application/json' \
  -d '{"batch_id":"BATCH_A","horizon_days":30,"target_weight_g":600,"target_date":"2026-10-30","use_llm":false}' \
  | python -m json.tool
