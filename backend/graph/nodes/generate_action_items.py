from datetime import datetime, timedelta


def run(state: dict) -> dict:
    state.setdefault("debug_trace", []).append("generate_action_items")
    start = datetime.strptime(state["planning_window"]["start_date"], "%Y-%m-%d").date()
    sampling_days = int(state.get("constraints", {}).get("sampling_interval_days", 14))
    actions = [
        {
            "date": (start + timedelta(days=sampling_days)).isoformat(),
            "priority": "medium",
            "task": "Perform a batch body measurement update.",
        }
    ]
    if state["risk_assessment"]["risk_level"] in {"medium", "high"}:
        actions.append(
            {
                "date": start.isoformat(),
                "priority": "high",
                "task": "Increase oxygen-focused inspection frequency for this batch.",
            }
        )
    state["action_items"] = actions
    return state
