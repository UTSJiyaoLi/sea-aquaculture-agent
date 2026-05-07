import { ProductionPlanResponse } from "../lib/types";

export function RiskCards({ plan }: { plan: ProductionPlanResponse }) {
  const items = plan.risk_assessment.risks;
  return (
    <div className="stack">
      <div className={`panel risk-card ${plan.risk_assessment.risk_level === "high" ? "high" : ""}`}>
        <h3>总体风险</h3>
        <strong>{plan.risk_assessment.risk_level.toUpperCase()}</strong>
      </div>
      {items.length ? (
        items.map((item, index) => (
          <div key={`${item.type}-${index}`} className={`panel risk-card ${item.level === "high" ? "high" : ""}`}>
            <h3>{item.type}</h3>
            <p>{item.message}</p>
          </div>
        ))
      ) : (
        <div className="panel risk-card">
          <p>当前没有额外风险触发项。</p>
        </div>
      )}
    </div>
  );
}
