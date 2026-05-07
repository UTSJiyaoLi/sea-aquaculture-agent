from pydantic import BaseModel


class AgentChatResponse(BaseModel):
    parsed_request: dict
    plan_response: dict
