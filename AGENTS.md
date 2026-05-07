# AGENTS.md

## Project

This repository implements an offshore aquaculture production planning agent.
The primary business object is a fish batch profile, not a single sensor or chat reply.

## First-phase scope

Implement a V1 production planning agent for arbitrary early-stage planning windows.

Must support:
- FastAPI backend
- LangGraph workflow
- Pydantic schemas
- CSV demo data
- Next.js local frontend
- SSH tunnel to remote backend
- Container or Apptainer plus tmux deployment on gpu6000
- Deterministic planning with `USE_LLM=false`

Do not implement real database integration, full sales planning, full R or MFPCA execution, auth, or heavy multi-agent orchestration in V1.

## Environment

Local frontend development:
- activate conda environment `rag_task`
- frontend runs in `apps/web`
- default frontend port `3007`

Remote backend:
- root directory `/share/home/lijiyao/CCCC/sea-aquaculture-agent`
- backend port `8797`
- bind backend to `127.0.0.1` where possible
- reuse existing vLLM services on `8001` and `8003`

## Code conventions

- Keep business logic in `backend/tools` and `backend/services`.
- Keep LangGraph node functions thin.
- Every graph node must append its node name to `debug_trace`.
- All production plan API responses must be structured JSON.
- The system must work when `USE_LLM=false`.
- Do not store secrets in the repository.
- Do not use `matplotlib.pyplot.show()` in backend request paths.
- Add tests for each tool or graph behavior that changes.

## Required validation

Run before marking work complete:
- `pytest -q`
- `bash scripts/smoke_test.sh`

If frontend files change:
- `cd apps/web`
- `npm run build`
