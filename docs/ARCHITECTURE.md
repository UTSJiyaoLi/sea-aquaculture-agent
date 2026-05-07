# Architecture

The V1 system is organized into a local frontend and a remote backend. The backend provides deterministic planning logic through FastAPI and LangGraph. The frontend renders structured planning results rather than a plain chat transcript.

## Backend

- `backend/app.py`: FastAPI entrypoint
- `backend/graph/`: planning workflow and state orchestration
- `backend/services/`: composition and service objects
- `backend/tools/`: deterministic business logic
- `backend/data/`: demo CSVs

## Frontend

- `apps/web/app/page.tsx`: workstation page
- `apps/web/components/`: cards, charts, tables, and forms
- `apps/web/lib/`: API client and shared types

## External dependencies

- Existing vLLM on `8001` and `8003`
- SSH tunnel for local access
- Optional future adapters for `Patent_fishi.py` and MFPCA
