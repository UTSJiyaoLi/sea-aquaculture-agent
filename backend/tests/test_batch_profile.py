from backend.app import planning_service


def test_batch_profile_computes_current_state() -> None:
    profile = planning_service.build_batch_profile("BATCH_A")
    assert profile["batch_id"] == "BATCH_A"
    assert profile["current_avg_weight_g"] == 120.5
    assert profile["current_estimated_count"] == 63000
    assert profile["estimated_biomass_kg"] == 7591.5
