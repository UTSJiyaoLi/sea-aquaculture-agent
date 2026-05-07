from typing import Any

from pydantic import BaseModel, Field, model_validator

from backend.schemas.common import ActionItem


class PlanningConstraints(BaseModel):
    max_feed_change_ratio_per_week: float = 0.15
    sampling_interval_days: int = 14
    risk_tolerance: str = "medium"


class ProductionPlanRequest(BaseModel):
    batch_id: str
    horizon_days: int | None = None
    planning_start: str | None = None
    planning_end: str | None = None
    target_weight_g: float | None = None
    target_date: str | None = None
    user_goal: str | None = None
    constraints: PlanningConstraints = Field(default_factory=PlanningConstraints)
    use_llm: bool = False

    @model_validator(mode="after")
    def validate_window(self) -> "ProductionPlanRequest":
        if self.horizon_days is None and not (self.planning_start and self.planning_end) and not (
            self.target_weight_g and self.target_date
        ):
            raise ValueError("Provide horizon_days, planning_start/planning_end, or target_weight_g/target_date.")
        return self


class AgentChatRequest(BaseModel):
    message: str
    batch_id: str | None = None
    use_llm: bool = False


class ProductionPlanResponse(BaseModel):
    request_id: str
    batch_id: str
    planning_window: dict[str, Any]
    current_state: dict[str, Any]
    data_quality: dict[str, Any]
    environment_summary: dict[str, Any]
    growth_prediction: dict[str, Any]
    production_plan: dict[str, Any]
    risk_assessment: dict[str, Any]
    action_items: list[ActionItem]
    assumptions: list[str]
    missing_data: list[str]
    explanation: str
    debug_trace: list[str]
