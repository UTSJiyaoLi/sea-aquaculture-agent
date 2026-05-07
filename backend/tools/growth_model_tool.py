from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from math import exp
from typing import Protocol


def _parse_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


class GrowthModelAdapter(Protocol):
    def predict(
        self,
        batch_profile: dict,
        environment_summary: dict,
        start_date: str,
        end_date: str,
        target_weight_g: float | None = None,
    ) -> dict:
        ...


@dataclass
class MockGrowthModelAdapter:
    default_target_weight_g: float = 600.0

    def predict(
        self,
        batch_profile: dict,
        environment_summary: dict,
        start_date: str,
        end_date: str,
        target_weight_g: float | None = None,
    ) -> dict:
        start = _parse_date(start_date)
        end = _parse_date(end_date)
        current_weight = float(batch_profile["current_avg_weight_g"])
        current_length = float(batch_profile["current_avg_length_cm"])
        survival_count = int(batch_profile["current_estimated_count"])
        target = float(target_weight_g or batch_profile.get("target_weight_g") or self.default_target_weight_g)
        avg_temp = float(environment_summary.get("avg_temperature_c") or 25.0)
        avg_do = float(environment_summary.get("avg_do_mg_l") or 6.0)
        optimal_temp = 25.0
        temp_factor = exp(-0.026 * ((avg_temp - optimal_temp) ** 2))
        if avg_do >= 6:
            do_factor = 1.0
        elif avg_do >= 5:
            do_factor = 0.85
        else:
            do_factor = 0.65

        days = max((end - start).days, 0)
        weight = current_weight
        length = current_length
        series: list[dict] = []
        estimated_target_date = None
        target_achievable = False

        for day_index in range(days + 1):
            current_day = start + timedelta(days=day_index)
            biomass_kg = round(weight * survival_count / 1000.0, 2)
            stage_feed_ratio = 0.042 if weight < 100 else 0.024 if weight < 400 else 0.015
            series.append(
                {
                    "date": current_day.isoformat(),
                    "day_index": day_index,
                    "avg_weight_g": round(weight, 2),
                    "avg_length_cm": round(length, 2),
                    "estimated_survival_count": survival_count,
                    "biomass_kg": biomass_kg,
                    "feed_recommendation_kg": round(biomass_kg * stage_feed_ratio, 2),
                }
            )
            if weight >= target and estimated_target_date is None:
                estimated_target_date = current_day.isoformat()
                target_achievable = True

            growth_rate = 0.035 * temp_factor * do_factor
            weight = weight + (growth_rate * weight * (1.0 - weight / max(target, self.default_target_weight_g)))
            length = length + max(weight / 5000.0, 0.015)

        if estimated_target_date is None:
            remaining_weight = max(target - weight, 1.0)
            extra_days = max(int(remaining_weight / max(weight * 0.005, 1.0)), 1)
            estimated_target_date = (end + timedelta(days=extra_days)).isoformat()

        return {
            "series": series,
            "estimated_target_date": estimated_target_date,
            "target_achievable": target_achievable,
            "model_name": "MockGrowthModelAdapter",
            "model_assumptions": [
                "Growth follows a logistic-style approximation.",
                "Temperature correction is centered at 25C.",
                "DO correction uses a deterministic piecewise rule.",
            ],
        }


class GrowthModelTool:
    def __init__(self, adapter: GrowthModelAdapter | None = None) -> None:
        self.adapter = adapter or MockGrowthModelAdapter()

    def predict(
        self,
        batch_profile: dict,
        environment_summary: dict,
        start_date: str,
        end_date: str,
        target_weight_g: float | None = None,
    ) -> dict:
        return self.adapter.predict(batch_profile, environment_summary, start_date, end_date, target_weight_g)
