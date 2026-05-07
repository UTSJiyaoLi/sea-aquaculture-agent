from backend.config import settings


class LlmService:
    def get_runtime_config(self) -> dict:
        return {
            "enabled": settings.use_llm,
            "openai_base_url": settings.openai_base_url,
            "openai_model": settings.openai_model,
            "planner_openai_base_url": settings.planner_openai_base_url,
            "planner_openai_model": settings.planner_openai_model,
        }
