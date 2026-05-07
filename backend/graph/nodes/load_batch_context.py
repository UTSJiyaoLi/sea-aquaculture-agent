from backend.services.production_planning_service import ProductionPlanningService
from backend.tools.database_tool import DatabaseQueryTool
from backend.tools.water_quality_tool import WaterQualityTool


def run(state: dict, planning_service: ProductionPlanningService, db: DatabaseQueryTool, water_quality: WaterQualityTool) -> dict:
    state.setdefault("debug_trace", []).append("load_batch_context")
    profile = planning_service.build_batch_profile(state["batch_id"])
    state["batch_profile"] = profile
    state["cage_id"] = profile["cage_id"]
    state["species"] = profile["species"]
    window = state.get("planning_window") or planning_service.normalize_planning_window(state, profile["latest_measurement_date"])
    state["planning_window"] = window
    state["body_measurements"] = db.get_body_measurements(state["batch_id"])
    state["feeding_records"] = db.get_feeding_records(state["batch_id"])
    state["mortality_records"] = db.get_mortality_records(state["batch_id"])
    state["water_quality_history"] = water_quality.get_history(profile["cage_id"], window["start_date"], window["end_date"])
    return state
