from backend.tools.growth_model_tool import GrowthModelTool


class ModelService:
    def __init__(self) -> None:
        self.growth_model_tool = GrowthModelTool()
