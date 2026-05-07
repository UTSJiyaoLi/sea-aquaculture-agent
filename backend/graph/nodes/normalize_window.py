from backend.services.production_planning_service import ProductionPlanningService


def run(state: dict, planning_service: ProductionPlanningService) -> dict:
    state.setdefault("debug_trace", []).append("normalize_planning_window")
    state["planning_window"] = planning_service.normalize_planning_window(state, state.get("batch_profile", {}).get("latest_measurement_date"))
    state["planning_mode"] = state["planning_window"]["mode"]
    return state
