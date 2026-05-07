# API

## GET /health

Returns service health and version.

## GET /api/batches

Returns the list of demo batches with computed summary fields.

## GET /api/batches/{batch_id}/profile

Returns the batch profile with current state and biomass estimate.

## POST /api/production/plan

Accepts:

- `horizon_days`
- `planning_start` and `planning_end`
- `target_weight_g` and `target_date`

Returns structured JSON for UI rendering:

- `planning_window`
- `current_state`
- `data_quality`
- `environment_summary`
- `growth_prediction`
- `production_plan`
- `risk_assessment`
- `action_items`
- `assumptions`
- `missing_data`
- `explanation`
- `debug_trace`

## POST /api/agent/chat

Parses a simple natural-language message into a production-planning request, then reuses `/api/production/plan`.
