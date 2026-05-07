from __future__ import annotations

from datetime import datetime


class RiskRuleTool:
    def assess(
        self,
        environment_summary: dict,
        growth_prediction: dict,
        data_quality: dict,
        target_weight_g: float | None = None,
        target_date: str | None = None,
    ) -> dict:
        risks = []
        rules_triggered = []
        if data_quality.get("missing_data"):
            risks.append(
                {
                    "type": "data_quality",
                    "level": "medium",
                    "message": "Some planning inputs are missing and assumptions were applied.",
                }
            )
            rules_triggered.append("missing_data")
        if data_quality.get("measurement_stale"):
            risks.append(
                {
                    "type": "data_quality",
                    "level": "medium",
                    "message": "Latest body measurement is stale relative to the planning window.",
                }
            )
            rules_triggered.append("measurement_stale")
        avg_do = environment_summary.get("avg_do_mg_l")
        min_do = environment_summary.get("min_do_mg_l")
        if avg_do is not None and avg_do < 5.0 or min_do is not None and min_do < 4.0:
            risks.append(
                {
                    "type": "oxygen",
                    "level": "high" if min_do is not None and min_do < 4.0 else "medium",
                    "message": "Dissolved oxygen is near or below the operational safety threshold.",
                }
            )
            rules_triggered.append("low_oxygen")
        min_temp = environment_summary.get("min_temperature_c")
        max_temp = environment_summary.get("max_temperature_c")
        if min_temp is not None and min_temp < 18 or max_temp is not None and max_temp > 30:
            risks.append(
                {
                    "type": "temperature",
                    "level": "medium",
                    "message": "Temperature has moved outside the preferred growout range.",
                }
            )
            rules_triggered.append("temperature_out_of_range")
        if target_weight_g and target_date:
            eta = growth_prediction.get("estimated_target_date")
            if eta and eta > target_date:
                risks.append(
                    {
                        "type": "growth_target",
                        "level": "high",
                        "message": f"Projected target date {eta} is later than requested target date {target_date}.",
                    }
                )
                rules_triggered.append("target_unachievable")
        risk_level = "low"
        if any(r["level"] == "high" for r in risks):
            risk_level = "high"
        elif risks:
            risk_level = "medium"
        return {
            "risk_level": risk_level,
            "risks": risks,
            "rules_triggered": rules_triggered,
        }
