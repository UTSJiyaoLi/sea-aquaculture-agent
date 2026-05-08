from __future__ import annotations

from pathlib import Path


class PatentFishiTool:
    def __init__(self, script_path: Path) -> None:
        self.script_path = script_path

    def describe(self) -> dict:
        return {
            "name": "patent_fishi",
            "kind": "growth_ecology_reference",
            "script_path": str(self.script_path),
            "enabled_in_request_path": False,
            "status": "reference_only",
            "notes": [
                "Backed by Patent_fishi.py.",
                "Not executed in the live request path because the source script is monolithic and plotting-oriented.",
                "Reserved for a future pure-function adapter replacement for the mock growth model.",
            ],
            "expected_outputs": [
                "fish_count",
                "individual_weight_g",
                "biomass_kg",
                "feed_kg",
                "temperature_c",
                "do_mg_l",
                "tn_mg_l",
                "tp_mg_l",
                "chlorophyll_c",
                "cumulative_emissions",
            ],
        }
