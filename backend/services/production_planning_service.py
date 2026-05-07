from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from typing import Any

from backend.services.data_service import CsvDataService
from backend.tools.biomass_tool import BiomassEstimationTool
from backend.tools.database_tool import DatabaseQueryTool
from backend.tools.feeding_plan_tool import FeedingPlanTool
from backend.tools.report_writer_tool import ReportWriterTool
from backend.tools.risk_rule_tool import RiskRuleTool
from backend.tools.tool_registry import ToolRegistry
from backend.tools.water_quality_tool import WaterQualityTool


class ProductionPlanningService:
    def __init__(self, registry: ToolRegistry) -> None:
        self.registry = registry

    @staticmethod
    def normalize_planning_window(request: dict[str, Any], latest_measurement_date: str | None = None) -> dict[str, Any]:
        today = datetime.strptime(latest_measurement_date or date.today().isoformat(), "%Y-%m-%d").date()
        horizon_days = request.get("horizon_days")
        planning_start = request.get("planning_start")
        planning_end = request.get("planning_end")
        target_date = request.get("target_date")
        if horizon_days is not None:
            start = today
            end = start + timedelta(days=int(horizon_days))
            mode = "future_plan"
        elif planning_start and planning_end:
            start = datetime.strptime(planning_start, "%Y-%m-%d").date()
            end = datetime.strptime(planning_end, "%Y-%m-%d").date()
            if end < today:
                mode = "historical_review"
            elif start <= today <= end:
                mode = "current_to_future"
            else:
                mode = "future_plan"
        else:
            start = today
            end = datetime.strptime(target_date, "%Y-%m-%d").date() if target_date else start + timedelta(days=30)
            mode = "target_backcast"
        return {
            "mode": mode,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "horizon_days": max((end - start).days, 0),
        }

    def build_batch_profile(self, batch_id: str) -> dict[str, Any]:
        db: DatabaseQueryTool = self.registry.get("database")
        biomass_tool: BiomassEstimationTool = self.registry.get("biomass")
        batch = db.get_batch(batch_id)
        measurements = db.get_body_measurements(batch_id)
        mortality = db.get_mortality_records(batch_id)
        latest = measurements[-1]
        current_estimated_count = batch.get("current_estimated_count")
        if not current_estimated_count:
            current_estimated_count = int(batch["initial_count"]) - sum(int(row["mortality_count"]) for row in mortality)
        biomass = biomass_tool.estimate_current(float(latest["avg_weight_g"]), int(current_estimated_count))
        return {
            **batch,
            "current_estimated_count": int(current_estimated_count),
            "current_avg_weight_g": float(latest["avg_weight_g"]),
            "current_avg_length_cm": float(latest["avg_length_cm"]),
            "estimated_biomass_kg": biomass["estimated_biomass_kg"],
            "latest_measurement_date": latest["measurement_date"],
        }

    def parse_chat_message(self, message: str, batch_id: str | None = None) -> dict[str, Any]:
        parsed = {
            "batch_id": batch_id or "BATCH_A",
            "horizon_days": 30,
            "target_weight_g": 600,
            "use_llm": False,
        }
        if "BATCH_B" in message or "B批" in message.upper():
            parsed["batch_id"] = "BATCH_B"
        if "A批" in message.upper():
            parsed["batch_id"] = "BATCH_A"
        digits = "".join(ch if ch.isdigit() else " " for ch in message).split()
        for idx, token in enumerate(digits):
            value = int(token)
            if "天" in message and value <= 365:
                parsed["horizon_days"] = value
            if "g" in message.lower() and value >= 100:
                parsed["target_weight_g"] = value
        return parsed

    def build_initial_state(self, request: dict[str, Any]) -> dict[str, Any]:
        return {
            "request_id": str(uuid.uuid4()),
            "batch_id": request["batch_id"],
            "planning_start": request.get("planning_start"),
            "planning_end": request.get("planning_end"),
            "horizon_days": request.get("horizon_days"),
            "target_weight_g": request.get("target_weight_g"),
            "target_date": request.get("target_date"),
            "constraints": request.get("constraints", {}),
            "use_llm": request.get("use_llm", False),
            "user_query": request.get("user_goal", ""),
            "debug_trace": [],
            "assumptions": [],
            "missing_data": [],
        }


def build_default_registry() -> ToolRegistry:
    data_service = CsvDataService()
    registry = ToolRegistry()
    registry.register("database", DatabaseQueryTool(data_service))
    registry.register("water_quality", WaterQualityTool(data_service))
    registry.register("biomass", BiomassEstimationTool())
    registry.register("feeding_plan", FeedingPlanTool())
    registry.register("risk_rule", RiskRuleTool())
    registry.register("report_writer", ReportWriterTool())
    return registry
