import { ProductionPlanResponse } from "../lib/types";

export function ChatPanel({ plan }: { plan: ProductionPlanResponse }) {
  return (
    <div className="stack">
      <h3>解释</h3>
      <p>{plan.explanation}</p>
      <h3>关键假设</h3>
      <ul>
        {plan.assumptions.map((item, index) => (
          <li key={`${item}-${index}`}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
