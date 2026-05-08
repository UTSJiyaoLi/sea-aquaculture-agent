from __future__ import annotations

from pathlib import Path


class WaterQualityMfpcaTool:
    def __init__(self, script_path: Path, data_path: Path) -> None:
        self.script_path = script_path
        self.data_path = data_path

    def describe(self) -> dict:
        return {
            "name": "water_quality_mfpca",
            "kind": "water_quality_analysis_reference",
            "script_path": str(self.script_path),
            "data_path": str(self.data_path),
            "enabled_in_request_path": False,
            "status": "reference_only",
            "notes": [
                "Backed by MFPCA_paper.R and surface_data_new_nodof.csv.",
                "Reserved for future offline or optional water-quality spatial analysis.",
                "Not required for the V1 production-planning request path.",
            ],
            "expected_capabilities": [
                "spatial_interpolation",
                "multivariate_functional_pca",
                "water_quality_warning_support",
            ],
        }
