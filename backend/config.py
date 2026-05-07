from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    app_name: str = "sea-aquaculture-agent"
    app_env: str = "development"
    backend_host: str = "127.0.0.1"
    backend_port: int = 8797
    frontend_port: int = 3007
    data_backend: str = "csv"
    demo_data_dir: str = "backend/data"
    use_llm: bool = False
    openai_api_key: str = "EMPTY"
    openai_base_url: str = "http://127.0.0.1:8001/v1"
    openai_model: str = "/share/home/lijiyao/CCCC/Models/vlms/Qwen3-VL-8B-Instruct"
    planner_openai_base_url: str = "http://127.0.0.1:8003/v1"
    planner_openai_model: str = "/share/home/lijiyao/CCCC/Models/llms/Llama-3.1-8B-Instruct"
    growth_model_backend: str = "mock"
    agent_debug: bool = True
    log_level: str = "INFO"
    remote_project_dir: str = "/share/home/lijiyao/CCCC/sea-aquaculture-agent"

    model_config = SettingsConfigDict(
        env_file=ROOT_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def demo_data_path(self) -> Path:
        return ROOT_DIR / self.demo_data_dir


settings = Settings()
