from pydantic import BaseModel


class BatchSummary(BaseModel):
    batch_id: str
    cage_id: str
    species: str
    current_avg_weight_g: float
    estimated_biomass_kg: float
    target_weight_g: float
    target_date: str


class BatchProfile(BaseModel):
    batch_id: str
    cage_id: str
    species: str
    stocking_date: str
    initial_count: int
    initial_avg_weight_g: float
    initial_avg_length_cm: float
    current_estimated_count: int
    current_avg_weight_g: float
    current_avg_length_cm: float
    estimated_biomass_kg: float
    target_weight_g: float
    target_date: str
    latest_measurement_date: str
