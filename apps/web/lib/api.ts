import { BatchSummary, ProductionPlanPayload, ProductionPlanResponse } from "./types";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:8797";

export async function fetchBatches(): Promise<BatchSummary[]> {
  const response = await fetch(`${API_BASE}/api/batches`, { cache: "no-store" });
  if (!response.ok) throw new Error("Failed to load batches.");
  return response.json();
}

export async function createPlan(payload: ProductionPlanPayload): Promise<ProductionPlanResponse> {
  const response = await fetch(`${API_BASE}/api/production/plan`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(await response.text());
  }
  return response.json();
}
