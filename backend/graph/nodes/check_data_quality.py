from datetime import datetime


def run(state: dict) -> dict:
    state.setdefault("debug_trace", []).append("check_data_quality")
    missing_data = state.setdefault("missing_data", [])
    warnings = []
    measurement_stale = False
    measurements = state.get("body_measurements", [])
    if not measurements:
        missing_data.append("body_measurements")
    else:
        latest = datetime.strptime(measurements[-1]["measurement_date"], "%Y-%m-%d").date()
        window_start = datetime.strptime(state["planning_window"]["start_date"], "%Y-%m-%d").date()
        if (window_start - latest).days > 21:
            measurement_stale = True
            warnings.append("Latest measurement is older than 21 days from planning start.")
    if not state.get("water_quality_history"):
        missing_data.append("water_quality_history")
        warnings.append("No water-quality records are available for the selected window.")
    state["data_quality"] = {
        "status": "usable" if not missing_data else "partial",
        "missing_data": missing_data,
        "warnings": warnings,
        "measurement_stale": measurement_stale,
    }
    return state
