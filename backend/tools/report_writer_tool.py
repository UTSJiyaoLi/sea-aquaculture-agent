from __future__ import annotations


class ReportWriterTool:
    def build_explanation(self, state: dict) -> str:
        risk_level = state["risk_assessment"]["risk_level"]
        target_date = state["growth_prediction"]["estimated_target_date"]
        batch_id = state["batch_id"]
        return (
            f"Batch {batch_id} was evaluated across the requested planning window. "
            f"The projected target date is {target_date}, and the current risk level is {risk_level}. "
            "Weekly actions are based on deterministic growth, feed, and water-quality rules."
        )
