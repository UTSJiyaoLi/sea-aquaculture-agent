from backend.tools.water_quality_tool import WaterQualityTool


def run(state: dict, water_quality: WaterQualityTool) -> dict:
    state.setdefault("debug_trace", []).append("summarize_environment")
    state["environment_summary"] = water_quality.summarize(state.get("water_quality_history", []))
    return state
