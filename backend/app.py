from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from backend.config import settings
from backend.graph.builder import build_graph
from backend.schemas.agent import AgentChatResponse
from backend.schemas.batch import BatchProfile, BatchSummary
from backend.schemas.production import AgentChatRequest, ProductionPlanRequest, ProductionPlanResponse
from backend.services.production_planning_service import ProductionPlanningService, build_default_registry
from backend.tools.biomass_tool import BiomassEstimationTool
from backend.tools.database_tool import DatabaseQueryTool
from backend.tools.feeding_plan_tool import FeedingPlanTool
from backend.tools.growth_model_tool import GrowthModelTool
from backend.tools.report_writer_tool import ReportWriterTool
from backend.tools.risk_rule_tool import RiskRuleTool
from backend.tools.water_quality_tool import WaterQualityTool

registry = build_default_registry()
planning_service = ProductionPlanningService(registry)
db: DatabaseQueryTool = registry.get("database")
water_quality: WaterQualityTool = registry.get("water_quality")
biomass_tool: BiomassEstimationTool = registry.get("biomass")
feeding_tool: FeedingPlanTool = registry.get("feeding_plan")
risk_tool: RiskRuleTool = registry.get("risk_rule")
report_writer: ReportWriterTool = registry.get("report_writer")
growth_tool = GrowthModelTool()
graph = build_graph(planning_service, db, water_quality, growth_tool, biomass_tool, feeding_tool, risk_tool, report_writer)

app = FastAPI(title="sea-aquaculture-agent")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "aquaculture-agent-api", "version": "0.1.0"}


@app.get("/api/batches", response_model=list[BatchSummary])
def list_batches() -> list[dict]:
    out = []
    for batch in db.list_batches():
        profile = planning_service.build_batch_profile(batch["batch_id"])
        out.append(
            {
                "batch_id": profile["batch_id"],
                "cage_id": profile["cage_id"],
                "species": profile["species"],
                "current_avg_weight_g": profile["current_avg_weight_g"],
                "estimated_biomass_kg": profile["estimated_biomass_kg"],
                "target_weight_g": profile["target_weight_g"],
                "target_date": profile["target_date"],
            }
        )
    return out


@app.get("/api/batches/{batch_id}/profile", response_model=BatchProfile)
def batch_profile(batch_id: str) -> dict:
    try:
        return planning_service.build_batch_profile(batch_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.post("/api/production/plan", response_model=ProductionPlanResponse)
def production_plan(request: ProductionPlanRequest) -> dict:
    try:
        state = planning_service.build_initial_state(request.model_dump())
        result = graph.invoke(state)
        return result["final_response"]
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/api/agent/chat", response_model=AgentChatResponse)
def agent_chat(request: AgentChatRequest) -> dict:
    parsed = planning_service.parse_chat_message(request.message, request.batch_id)
    if request.use_llm:
        parsed["use_llm"] = True
    plan = production_plan(ProductionPlanRequest(**parsed))
    return {"parsed_request": parsed, "plan_response": plan}
