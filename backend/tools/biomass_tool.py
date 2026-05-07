from __future__ import annotations


class BiomassEstimationTool:
    def estimate_current(self, avg_weight_g: float, survival_count: int) -> dict:
        biomass_kg = round(avg_weight_g * survival_count / 1000.0, 2)
        return {
            "avg_weight_g": round(avg_weight_g, 2),
            "survival_count": int(survival_count),
            "estimated_biomass_kg": biomass_kg,
        }

    def estimate_series(self, growth_series: list[dict], survival_count: int) -> list[dict]:
        out: list[dict] = []
        for row in growth_series:
            biomass_kg = round(float(row["avg_weight_g"]) * survival_count / 1000.0, 2)
            merged = dict(row)
            merged["biomass_kg"] = biomass_kg
            out.append(merged)
        return out
