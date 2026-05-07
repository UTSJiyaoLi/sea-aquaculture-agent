from typing import Any, Literal, TypedDict


PlanningMode = Literal[
    "future_plan",
    "current_to_future",
    "historical_review",
    "target_backcast",
]


class AgentState(TypedDict, total=False):
    request_id: str
    user_query: str
    task_type: str
    batch_id: str
    cage_id: str
    species: str
    planning_start: str | None
    planning_end: str | None
    horizon_days: int | None
    target_weight_g: float | None
    target_date: str | None
    planning_mode: PlanningMode
    constraints: dict[str, Any]
    use_llm: bool
    planning_window: dict[str, Any]
    batch_profile: dict[str, Any]
    water_quality_history: list[dict[str, Any]]
    body_measurements: list[dict[str, Any]]
    feeding_records: list[dict[str, Any]]
    mortality_records: list[dict[str, Any]]
    data_quality: dict[str, Any]
    environment_summary: dict[str, Any]
    growth_prediction: dict[str, Any]
    biomass_estimation: dict[str, Any]
    production_plan: dict[str, Any]
    risk_assessment: dict[str, Any]
    action_items: list[dict[str, Any]]
    assumptions: list[str]
    missing_data: list[str]
    debug_trace: list[str]
    current_state: dict[str, Any]
    explanation: str
    final_response: dict[str, Any]
    error: str | None
