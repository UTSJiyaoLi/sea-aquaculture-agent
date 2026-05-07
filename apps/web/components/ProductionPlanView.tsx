import { ProductionPlanResponse } from "../lib/types";
import { GrowthCurve } from "./GrowthCurve";
import { WeeklyPlanTable } from "./WeeklyPlanTable";

export function ProductionPlanView({ plan }: { plan: ProductionPlanResponse }) {
  return (
    <div className="stack">
      <div className="grid-two">
        <div className="metric">
          <span>当前均重</span>
          <strong>{plan.current_state.current_avg_weight_g} g</strong>
        </div>
        <div className="metric">
          <span>当前生物量</span>
          <strong>{plan.current_state.estimated_biomass_kg} kg</strong>
        </div>
        <div className="metric">
          <span>规划模式</span>
          <strong>{plan.planning_window.mode}</strong>
        </div>
        <div className="metric">
          <span>目标是否已达成</span>
          <strong>{plan.growth_prediction.target_achievable ? "可达" : "待推进"}</strong>
        </div>
      </div>
      <div className="panel">
        <h3>增长预测</h3>
        <GrowthCurve plan={plan} />
      </div>
      <div className="panel">
        <h3>分周生产计划</h3>
        <p>{plan.production_plan.summary}</p>
        <WeeklyPlanTable plan={plan} />
      </div>
    </div>
  );
}
