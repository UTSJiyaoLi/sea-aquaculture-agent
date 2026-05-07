from backend.tools.report_writer_tool import ReportWriterTool


def run(state: dict, report_writer: ReportWriterTool) -> dict:
    state.setdefault("debug_trace", []).append("write_response")
    state["assumptions"].extend(
        [
            "V1 planning uses demo CSV inputs for batch operations.",
            "Raw water-quality and ecology scripts are retained as reference, not as primary request-path dependencies.",
        ]
    )
    state["explanation"] = report_writer.build_explanation(state)
    state["final_response"] = {
        "request_id": state["request_id"],
        "batch_id": state["batch_id"],
        "planning_window": state["planning_window"],
        "current_state": state["current_state"],
        "data_quality": state["data_quality"],
        "environment_summary": state["environment_summary"],
        "growth_prediction": state["growth_prediction"],
        "production_plan": state["production_plan"],
        "risk_assessment": state["risk_assessment"],
        "action_items": state["action_items"],
        "assumptions": state["assumptions"],
        "missing_data": state["missing_data"],
        "explanation": state["explanation"],
        "debug_trace": state["debug_trace"],
    }
    return state
