from __future__ import annotations

from typing import Any

import pandas as pd

from backend.services.data_service import CsvDataService


class DatabaseQueryTool:
    def __init__(self, data_service: CsvDataService) -> None:
        self.data_service = data_service

    @staticmethod
    def _filter_window(df: pd.DataFrame, column: str, start: str | None, end: str | None) -> pd.DataFrame:
        if start:
            df = df[df[column] >= start]
        if end:
            df = df[df[column] <= end]
        return df

    def list_batches(self) -> list[dict[str, Any]]:
        return self.data_service.batches().to_dict(orient="records")

    def get_batch(self, batch_id: str) -> dict[str, Any]:
        df = self.data_service.batches()
        recs = df[df["batch_id"] == batch_id].to_dict(orient="records")
        if not recs:
            raise KeyError(f"Batch not found: {batch_id}")
        return recs[0]

    def get_body_measurements(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict[str, Any]]:
        df = self.data_service.body_measurements()
        df = df[df["batch_id"] == batch_id]
        df = self._filter_window(df, "measurement_date", start, end)
        return df.sort_values("measurement_date").to_dict(orient="records")

    def get_feeding_records(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict[str, Any]]:
        df = self.data_service.feeding_records()
        df = df[df["batch_id"] == batch_id]
        df = self._filter_window(df, "date", start, end)
        return df.sort_values("date").to_dict(orient="records")

    def get_mortality_records(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict[str, Any]]:
        df = self.data_service.mortality_records()
        df = df[df["batch_id"] == batch_id]
        df = self._filter_window(df, "date", start, end)
        return df.sort_values("date").to_dict(orient="records")
