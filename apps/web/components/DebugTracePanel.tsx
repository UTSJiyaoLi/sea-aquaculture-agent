import { ProductionPlanResponse } from "../lib/types";

export function DebugTracePanel({ plan }: { plan: ProductionPlanResponse }) {
  return (
    <div className="stack">
      <div className="badge">执行链路</div>
      <pre className="mono">{plan.debug_trace.join("\n")}</pre>
    </div>
  );
}
