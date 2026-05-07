"use client";

import { BatchSummary } from "../lib/types";
import { BatchSelector } from "./BatchSelector";

type FormState = {
  batch_id: string;
  horizon_days: number;
  target_weight_g: number;
  target_date: string;
  planning_start: string;
  planning_end: string;
  use_llm: boolean;
  user_goal: string;
};

export function PlanningWindowForm({
  batches,
  form,
  loading,
  onChange,
  onSubmit,
}: {
  batches: BatchSummary[];
  form: FormState;
  loading: boolean;
  onChange: (form: FormState) => void;
  onSubmit: () => void;
}) {
  return (
    <div className="stack">
      <BatchSelector batches={batches} value={form.batch_id} onChange={(batch_id) => onChange({ ...form, batch_id })} />
      <label className="label">
        未来天数
        <input
          type="number"
          value={form.horizon_days}
          onChange={(event) => onChange({ ...form, horizon_days: Number(event.target.value) })}
        />
      </label>
      <div className="grid-two">
        <label className="label">
          目标体重(g)
          <input
            type="number"
            value={form.target_weight_g}
            onChange={(event) => onChange({ ...form, target_weight_g: Number(event.target.value) })}
          />
        </label>
        <label className="label">
          目标日期
          <input
            type="date"
            value={form.target_date}
            onChange={(event) => onChange({ ...form, target_date: event.target.value })}
          />
        </label>
      </div>
      <div className="grid-two">
        <label className="label">
          规划开始
          <input
            type="date"
            value={form.planning_start}
            onChange={(event) => onChange({ ...form, planning_start: event.target.value })}
          />
        </label>
        <label className="label">
          规划结束
          <input
            type="date"
            value={form.planning_end}
            onChange={(event) => onChange({ ...form, planning_end: event.target.value })}
          />
        </label>
      </div>
      <label className="label">
        需求描述
        <textarea
          rows={4}
          value={form.user_goal}
          onChange={(event) => onChange({ ...form, user_goal: event.target.value })}
        />
      </label>
      <label className="label">
        <span>
          <input
            type="checkbox"
            checked={form.use_llm}
            onChange={(event) => onChange({ ...form, use_llm: event.target.checked })}
          />{" "}
          使用现有大模型服务增强解释
        </span>
      </label>
      <button className="primary" disabled={loading} onClick={onSubmit}>
        {loading ? "生成中..." : "生成生产计划"}
      </button>
    </div>
  );
}
