from fastapi.testclient import TestClient

from backend.app import app


client = TestClient(app)


def test_production_plan_response_shape() -> None:
    response = client.post(
        "/api/production/plan",
        json={
            "batch_id": "BATCH_A",
            "horizon_days": 30,
            "target_weight_g": 600,
            "target_date": "2026-10-30",
            "use_llm": False,
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["batch_id"] == "BATCH_A"
    assert payload["planning_window"]["mode"] == "future_plan"
    assert payload["growth_prediction"]["series"]
    assert payload["production_plan"]["weekly_plan"]
    assert payload["risk_assessment"]["risk_level"] in {"low", "medium", "high"}
    assert payload["debug_trace"] == [
        "parse_intent",
        "load_batch_context",
        "normalize_planning_window",
        "check_data_quality",
        "summarize_environment",
        "run_growth_projection",
        "estimate_biomass",
        "assess_risk",
        "generate_feeding_plan",
        "generate_action_items",
        "write_response",
    ]
