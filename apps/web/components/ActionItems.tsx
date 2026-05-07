import { ProductionPlanResponse } from "../lib/types";

export function ActionItems({ plan }: { plan: ProductionPlanResponse }) {
  return (
    <div className="stack">
      {plan.action_items.map((item, index) => (
        <div className="metric" key={`${item.date}-${index}`}>
          <div className="badge">{item.priority}</div>
          <strong>{item.date}</strong>
          <div>{item.task}</div>
        </div>
      ))}
    </div>
  );
}
