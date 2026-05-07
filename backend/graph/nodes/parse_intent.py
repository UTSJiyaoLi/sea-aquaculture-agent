def run(state: dict) -> dict:
    state.setdefault("debug_trace", []).append("parse_intent")
    return state
