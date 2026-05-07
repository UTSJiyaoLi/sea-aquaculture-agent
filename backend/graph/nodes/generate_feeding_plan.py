from backend.tools.feeding_plan_tool import FeedingPlanTool


def run(state: dict, feeding_tool: FeedingPlanTool) -> dict:
    state.setdefault("debug_trace", []).append("generate_feeding_plan")
    state["production_plan"] = feeding_tool.generate_weekly_plan(
        state["growth_prediction"],
        state["batch_profile"],
        state.get("risk_assessment"),
        state.get("constraints", {}),
    )
    return state
