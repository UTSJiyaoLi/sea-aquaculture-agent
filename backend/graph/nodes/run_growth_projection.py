from backend.tools.growth_model_tool import GrowthModelTool


def run(state: dict, growth_tool: GrowthModelTool) -> dict:
    state.setdefault("debug_trace", []).append("run_growth_projection")
    window = state["planning_window"]
    target_weight = state.get("target_weight_g") or state["batch_profile"].get("target_weight_g")
    state["growth_prediction"] = growth_tool.predict(
        batch_profile=state["batch_profile"],
        environment_summary=state["environment_summary"],
        start_date=window["start_date"],
        end_date=window["end_date"],
        target_weight_g=target_weight,
    )
    state["assumptions"].extend(state["growth_prediction"].get("model_assumptions", []))
    return state
