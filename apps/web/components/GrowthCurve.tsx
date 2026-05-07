import { ProductionPlanResponse } from "../lib/types";

export function GrowthCurve({ plan }: { plan: ProductionPlanResponse }) {
  const points = plan.growth_prediction.series;
  if (!points.length) return null;
  const maxWeight = Math.max(...points.map((item) => item.avg_weight_g));
  const minWeight = Math.min(...points.map((item) => item.avg_weight_g));
  const width = 760;
  const height = 240;
  const padding = 18;
  const path = points
    .map((point, index) => {
      const x = padding + (index / Math.max(points.length - 1, 1)) * (width - padding * 2);
      const normalized = (point.avg_weight_g - minWeight) / Math.max(maxWeight - minWeight, 1);
      const y = height - padding - normalized * (height - padding * 2);
      return `${index === 0 ? "M" : "L"} ${x} ${y}`;
    })
    .join(" ");

  return (
    <div className="stack">
      <div className="badge">预计达标时间：{plan.growth_prediction.estimated_target_date}</div>
      <svg className="chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Growth curve">
        <path d={path} fill="none" stroke="#0f766e" strokeWidth="3" />
      </svg>
    </div>
  );
}
