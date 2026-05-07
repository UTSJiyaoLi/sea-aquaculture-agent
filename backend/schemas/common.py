from typing import Literal

from pydantic import BaseModel


PlanningMode = Literal[
    "future_plan",
    "current_to_future",
    "historical_review",
    "target_backcast",
]


class ActionItem(BaseModel):
    date: str
    priority: Literal["low", "medium", "high"]
    task: str


class RiskItem(BaseModel):
    type: str
    level: Literal["low", "medium", "high"]
    message: str
