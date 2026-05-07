from langgraph.graph import END, StateGraph

from backend.graph.nodes import (
    assess_risk,
    check_data_quality,
    estimate_biomass,
    generate_action_items,
    generate_feeding_plan,
    load_batch_context,
    normalize_window,
    parse_intent,
    run_growth_projection,
    summarize_environment,
    write_response,
)
from backend.graph.state import AgentState
from backend.services.production_planning_service import ProductionPlanningService
from backend.tools.biomass_tool import BiomassEstimationTool
from backend.tools.database_tool import DatabaseQueryTool
from backend.tools.feeding_plan_tool import FeedingPlanTool
from backend.tools.growth_model_tool import GrowthModelTool
from backend.tools.report_writer_tool import ReportWriterTool
from backend.tools.risk_rule_tool import RiskRuleTool
from backend.tools.water_quality_tool import WaterQualityTool


def build_graph(
    planning_service: ProductionPlanningService,
    db: DatabaseQueryTool,
    water_quality: WaterQualityTool,
    growth_tool: GrowthModelTool,
    biomass_tool: BiomassEstimationTool,
    feeding_tool: FeedingPlanTool,
    risk_tool: RiskRuleTool,
    report_writer: ReportWriterTool,
):
    graph = StateGraph(AgentState)
    graph.add_node("parse_intent", parse_intent.run)
    graph.add_node("normalize_planning_window", lambda state: normalize_window.run(state, planning_service))
    graph.add_node("load_batch_context", lambda state: load_batch_context.run(state, planning_service, db, water_quality))
    graph.add_node("check_data_quality", check_data_quality.run)
    graph.add_node("summarize_environment", lambda state: summarize_environment.run(state, water_quality))
    graph.add_node("run_growth_projection", lambda state: run_growth_projection.run(state, growth_tool))
    graph.add_node("estimate_biomass", lambda state: estimate_biomass.run(state, biomass_tool))
    graph.add_node("generate_feeding_plan", lambda state: generate_feeding_plan.run(state, feeding_tool))
    graph.add_node("assess_risk", lambda state: assess_risk.run(state, risk_tool))
    graph.add_node("generate_action_items", generate_action_items.run)
    graph.add_node("write_response", lambda state: write_response.run(state, report_writer))

    graph.set_entry_point("parse_intent")
    graph.add_edge("parse_intent", "load_batch_context")
    graph.add_edge("load_batch_context", "normalize_planning_window")
    graph.add_edge("normalize_planning_window", "check_data_quality")
    graph.add_edge("check_data_quality", "summarize_environment")
    graph.add_edge("summarize_environment", "run_growth_projection")
    graph.add_edge("run_growth_projection", "estimate_biomass")
    graph.add_edge("estimate_biomass", "assess_risk")
    graph.add_edge("assess_risk", "generate_feeding_plan")
    graph.add_edge("generate_feeding_plan", "generate_action_items")
    graph.add_edge("generate_action_items", "write_response")
    graph.add_edge("write_response", END)
    return graph.compile()
