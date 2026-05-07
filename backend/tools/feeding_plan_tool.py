from __future__ import annotations

from datetime import datetime, timedelta


class FeedingPlanTool:
    def generate_weekly_plan(
        self,
        growth_prediction: dict,
        batch_profile: dict,
        risk_assessment: dict | None,
        constraints: dict,
    ) -> dict:
        weekly_plan = []
        series = growth_prediction.get("series", [])
        max_change = float(constraints.get("max_feed_change_ratio_per_week", 0.15))
        sampling_interval_days = int(constraints.get("sampling_interval_days", 14))
        current_feed = None
        for week_index, start_idx in enumerate(range(0, len(series), 7), start=1):
            week_slice = series[start_idx : start_idx + 7]
            if not week_slice:
                continue
            avg_feed = sum(float(item["feed_recommendation_kg"]) for item in week_slice) / len(week_slice)
            if current_feed is not None:
                upper = current_feed * (1 + max_change)
                lower = current_feed * (1 - max_change)
                avg_feed = max(min(avg_feed, upper), lower)
            current_feed = avg_feed
            avg_weight = week_slice[-1]["avg_weight_g"]
            stage = "juvenile" if avg_weight < 100 else "growout" if avg_weight < 400 else "pre_harvest"
            start_date = datetime.strptime(week_slice[0]["date"], "%Y-%m-%d").date()
            end_date = datetime.strptime(week_slice[-1]["date"], "%Y-%m-%d").date()
            next_sampling = (start_date + timedelta(days=sampling_interval_days)).isoformat()
            inspection_plan = "Inspect twice daily and prioritize dawn oxygen checks."
            if risk_assessment and risk_assessment.get("risk_level") == "high":
                inspection_plan = "Inspect at least three times daily and add pre-dawn oxygen checks."
            weekly_plan.append(
                {
                    "week_index": week_index,
                    "date_range": [start_date.isoformat(), end_date.isoformat()],
                    "growth_stage": stage,
                    "feeding_strategy": f"Keep feed adjustments within {int(max_change * 100)}% week over week.",
                    "estimated_daily_feed_kg": round(avg_feed, 2),
                    "sampling_plan": f"Next body measurement is scheduled for {next_sampling}.",
                    "inspection_plan": inspection_plan,
                }
            )
        return {
            "summary": "Use stable weekly feed adjustments, regular sampling, and oxygen-aware inspection.",
            "weekly_plan": weekly_plan,
        }
