import { ProductionPlanResponse } from "../lib/types";

export function WeeklyPlanTable({ plan }: { plan: ProductionPlanResponse }) {
  return (
    <table className="table">
      <thead>
        <tr>
          <th>周次</th>
          <th>日期</th>
          <th>阶段</th>
          <th>日投喂(kg)</th>
          <th>采样</th>
        </tr>
      </thead>
      <tbody>
        {plan.production_plan.weekly_plan.map((item) => (
          <tr key={item.week_index}>
            <td>{item.week_index}</td>
            <td>
              {item.date_range[0]} 至 {item.date_range[1]}
            </td>
            <td>{item.growth_stage}</td>
            <td>{item.estimated_daily_feed_kg}</td>
            <td>{item.sampling_plan}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
