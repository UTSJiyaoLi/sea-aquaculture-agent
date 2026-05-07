export type BatchSummary = {
  batch_id: string;
  cage_id: string;
  species: string;
  current_avg_weight_g: number;
  estimated_biomass_kg: number;
  target_weight_g: number;
  target_date: string;
};

export type ProductionPlanPayload = {
  batch_id: string;
  horizon_days?: number;
  planning_start?: string;
  planning_end?: string;
  target_weight_g?: number;
  target_date?: string;
  user_goal?: string;
  use_llm: boolean;
  constraints: {
    max_feed_change_ratio_per_week: number;
    sampling_interval_days: number;
    risk_tolerance: string;
  };
};

export type ProductionPlanResponse = {
  request_id: string;
  batch_id: string;
  planning_window: { mode: string; start_date: string; end_date: string; horizon_days: number };
  current_state: {
    current_avg_weight_g: number;
    current_avg_length_cm: number;
    estimated_survival_count: number;
    estimated_biomass_kg: number;
  };
  data_quality: { status: string; missing_data: string[]; warnings: string[] };
  environment_summary: Record<string, string | number | null | string[]>;
  growth_prediction: {
    estimated_target_date: string;
    target_achievable: boolean;
    series: Array<{
      date: string;
      avg_weight_g: number;
      biomass_kg: number;
      feed_recommendation_kg: number;
    }>;
  };
  production_plan: {
    summary: string;
    weekly_plan: Array<{
      week_index: number;
      date_range: [string, string];
      growth_stage: string;
      feeding_strategy: string;
      estimated_daily_feed_kg: number;
      sampling_plan: string;
      inspection_plan: string;
    }>;
  };
  risk_assessment: {
    risk_level: "low" | "medium" | "high";
    risks: Array<{ type: string; level: string; message: string }>;
  };
  action_items: Array<{ date: string; priority: string; task: string }>;
  assumptions: string[];
  missing_data: string[];
  explanation: string;
  debug_trace: string[];
};
