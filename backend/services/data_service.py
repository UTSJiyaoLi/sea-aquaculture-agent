from __future__ import annotations

from functools import lru_cache
from pathlib import Path

import pandas as pd

from backend.config import settings


class CsvDataService:
    def __init__(self, data_dir: Path | None = None) -> None:
        self.data_dir = data_dir or settings.demo_data_path

    @lru_cache(maxsize=None)
    def load_csv(self, filename: str) -> pd.DataFrame:
        return pd.read_csv(self.data_dir / filename)

    def batches(self) -> pd.DataFrame:
        return self.load_csv("demo_batches.csv").copy()

    def body_measurements(self) -> pd.DataFrame:
        return self.load_csv("demo_body_measurements.csv").copy()

    def water_quality(self) -> pd.DataFrame:
        return self.load_csv("demo_water_quality.csv").copy()

    def feeding_records(self) -> pd.DataFrame:
        return self.load_csv("demo_feeding_records.csv").copy()

    def mortality_records(self) -> pd.DataFrame:
        return self.load_csv("demo_mortality_records.csv").copy()
