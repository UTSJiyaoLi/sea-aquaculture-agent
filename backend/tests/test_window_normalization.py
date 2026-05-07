from backend.app import planning_service


def test_normalize_future_plan() -> None:
    out = planning_service.normalize_planning_window({"horizon_days": 30}, "2026-06-01")
    assert out["mode"] == "future_plan"
    assert out["start_date"] == "2026-06-01"
    assert out["horizon_days"] == 30


def test_normalize_date_range() -> None:
    out = planning_service.normalize_planning_window(
        {"planning_start": "2026-05-25", "planning_end": "2026-06-10"},
        "2026-06-01",
    )
    assert out["mode"] == "current_to_future"


def test_normalize_target_backcast() -> None:
    out = planning_service.normalize_planning_window(
        {"target_weight_g": 600, "target_date": "2026-10-30"},
        "2026-06-01",
    )
    assert out["mode"] == "target_backcast"


def test_normalize_historical_review() -> None:
    out = planning_service.normalize_planning_window(
        {"planning_start": "2026-05-01", "planning_end": "2026-05-20"},
        "2026-06-01",
    )
    assert out["mode"] == "historical_review"
