from backend.tools.growth_model_tool import GrowthModelTool


def test_growth_projection_outputs_series() -> None:
    tool = GrowthModelTool()
    result = tool.predict(
        batch_profile={
            "current_avg_weight_g": 120.5,
            "current_avg_length_cm": 18.2,
            "current_estimated_count": 63000,
            "target_weight_g": 600,
        },
        environment_summary={"avg_temperature_c": 24.5, "avg_do_mg_l": 6.2},
        start_date="2026-06-01",
        end_date="2026-06-30",
        target_weight_g=600,
    )
    assert result["series"]
    assert "estimated_target_date" in result
    assert "target_achievable" in result
