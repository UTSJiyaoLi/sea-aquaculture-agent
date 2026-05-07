# Sea Aquaculture Agent

Sea Aquaculture Agent is a V1 offshore aquaculture production planning system. It reads demo batch data, water-quality history, body measurements, feeding records, and mortality records, then produces a structured plan for an arbitrary planning window.

The system is split into:

- a remote FastAPI + LangGraph backend on `gpu6000`
- a local Next.js workstation UI
- optional reuse of existing vLLM services for explanation and chat enhancement

## Core capabilities

- Batch list and batch profile APIs
- Planning-window normalization
- Growth projection with a deterministic mock model
- Biomass estimation, feeding planning, risk assessment, and action items
- Structured JSON responses suitable for UI rendering

## Local frontend development

```bash
conda activate rag_task
cd apps/web
npm install
set NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8797
npm run dev -- --port 3007
```

The backend is intended to run on the server only. Local development should connect to the remote backend through the SSH tunnel.

On Windows you can also use:

- `deploy\local_start_frontend.cmd`
- `deploy\local_start_frontend.ps1`

## Remote deployment

See [DEPLOYMENT.md](C:\sea-aquaculture-agent\docs\DEPLOYMENT.md).

## Data sources

- Production-planning APIs use demo CSVs in `backend/data`
- `Data/surface_data_new_nodof.csv` remains as raw reference input for future water-quality analysis
- `Patent_fishi.py` remains as the reference growth and ecology script for later adapter work
