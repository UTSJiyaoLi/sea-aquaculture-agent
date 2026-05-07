from backend.tools.risk_rule_tool import RiskRuleTool


def run(state: dict, risk_tool: RiskRuleTool) -> dict:
    state.setdefault("debug_trace", []).append("assess_risk")
    state["risk_assessment"] = risk_tool.assess(
        environment_summary=state["environment_summary"],
        growth_prediction=state["growth_prediction"],
        data_quality=state["data_quality"],
        target_weight_g=state.get("target_weight_g"),
        target_date=state.get("target_date"),
    )
    return state
