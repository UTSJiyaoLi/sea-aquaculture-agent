from typing import Any

from pydantic import BaseModel


class AgentChatResponse(BaseModel):
    intent: str
    route: str
    parsed_request: dict[str, Any]
    plan_response: dict[str, Any] | None = None
    tool_result: dict[str, Any] | None = None
