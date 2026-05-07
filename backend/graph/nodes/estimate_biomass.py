from backend.tools.biomass_tool import BiomassEstimationTool


def run(state: dict, biomass_tool: BiomassEstimationTool) -> dict:
    state.setdefault("debug_trace", []).append("estimate_biomass")
    survival_count = int(state["batch_profile"]["current_estimated_count"])
    series = biomass_tool.estimate_series(state["growth_prediction"]["series"], survival_count)
    state["growth_prediction"]["series"] = series
    state["biomass_estimation"] = biomass_tool.estimate_current(
        float(state["batch_profile"]["current_avg_weight_g"]),
        survival_count,
    )
    state["current_state"] = {
        "current_avg_weight_g": float(state["batch_profile"]["current_avg_weight_g"]),
        "current_avg_length_cm": float(state["batch_profile"]["current_avg_length_cm"]),
        "estimated_survival_count": survival_count,
        "estimated_biomass_kg": float(state["batch_profile"]["estimated_biomass_kg"]),
    }
    return state
