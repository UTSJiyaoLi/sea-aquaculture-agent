from __future__ import annotations

from typing import Any

from backend.services.data_service import CsvDataService


class WaterQualityTool:
    def __init__(self, data_service: CsvDataService) -> None:
        self.data_service = data_service

    def get_history(self, cage_id: str, start: str | None = None, end: str | None = None) -> list[dict[str, Any]]:
        df = self.data_service.water_quality()
        df = df[df["cage_id"] == cage_id]
        if start:
            df = df[df["timestamp"] >= f"{start}T00:00:00"]
        if end:
            df = df[df["timestamp"] <= f"{end}T23:59:59"]
        return df.sort_values("timestamp").to_dict(orient="records")

    def summarize(self, records: list[dict[str, Any]]) -> dict[str, Any]:
        if not records:
            return {
                "avg_temperature_c": None,
                "min_temperature_c": None,
                "max_temperature_c": None,
                "avg_do_mg_l": None,
                "min_do_mg_l": None,
                "avg_salinity_ppt": None,
                "avg_ph": None,
                "record_count": 0,
                "risk_notes": ["No water-quality records found for the planning window."],
            }
        temps = [float(r["temperature_c"]) for r in records]
        dos = [float(r["do_mg_l"]) for r in records]
        salinity = [float(r["salinity_ppt"]) for r in records]
        ph_vals = [float(r["ph"]) for r in records]
        risk_notes: list[str] = []
        if min(dos) < 4.0:
            risk_notes.append("Nighttime low-oxygen events are present in the selected water-quality history.")
        if max(temps) > 30 or min(temps) < 18:
            risk_notes.append("Temperature has moved outside the preferred growout range.")
        return {
            "avg_temperature_c": round(sum(temps) / len(temps), 2),
            "min_temperature_c": round(min(temps), 2),
            "max_temperature_c": round(max(temps), 2),
            "avg_do_mg_l": round(sum(dos) / len(dos), 2),
            "min_do_mg_l": round(min(dos), 2),
            "avg_salinity_ppt": round(sum(salinity) / len(salinity), 2),
            "avg_ph": round(sum(ph_vals) / len(ph_vals), 2),
            "record_count": len(records),
            "risk_notes": risk_notes,
        }
