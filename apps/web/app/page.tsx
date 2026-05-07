"use client";

import { useEffect, useState } from "react";

import { ActionItems } from "../components/ActionItems";
import { ChatPanel } from "../components/ChatPanel";
import { DebugTracePanel } from "../components/DebugTracePanel";
import { PlanningWindowForm } from "../components/PlanningWindowForm";
import { ProductionPlanView } from "../components/ProductionPlanView";
import { RiskCards } from "../components/RiskCards";
import { createPlan, fetchBatches } from "../lib/api";
import { BatchSummary, ProductionPlanResponse } from "../lib/types";

export default function Page() {
  const [batches, setBatches] = useState<BatchSummary[]>([]);
  const [plan, setPlan] = useState<ProductionPlanResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({
    batch_id: "BATCH_A",
    horizon_days: 30,
    target_weight_g: 600,
    target_date: "2026-10-30",
    planning_start: "",
    planning_end: "",
    use_llm: false,
    user_goal: "希望控制风险，并尽量按目标规格稳步推进。",
  });

  useEffect(() => {
    fetchBatches()
      .then((items) => {
        setBatches(items);
        if (items[0]) {
          setForm((current) => ({
            ...current,
            batch_id: items[0].batch_id,
            target_weight_g: items[0].target_weight_g,
            target_date: items[0].target_date,
          }));
        }
      })
      .catch((err) => setError(err.message));
  }, []);

  async function handleSubmit() {
    setLoading(true);
    setError(null);
    try {
      const response = await createPlan({
        batch_id: form.batch_id,
        horizon_days: form.horizon_days,
        planning_start: form.planning_start || undefined,
        planning_end: form.planning_end || undefined,
        target_weight_g: form.target_weight_g,
        target_date: form.target_date,
        user_goal: form.user_goal,
        use_llm: form.use_llm,
        constraints: {
          max_feed_change_ratio_per_week: 0.15,
          sampling_interval_days: 14,
          risk_tolerance: "medium",
        },
      });
      setPlan(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="page-shell">
      <section className="hero hero-grid">
        <div className="hero-copy">
          <div className="hero-kicker">Deep-Sea Planning Console</div>
          <h1>深远海养殖前期生产规划工作台</h1>
          <p>
            前端只负责操作和展示，后端规划服务固定部署在服务器上，通过 SSH 隧道访问远端
            FastAPI 与 LangGraph 工作流。
          </p>
          <div className="hero-tags">
            <span className="badge">Remote Backend Only</span>
            <span className="badge">Batch-Centric Planning</span>
            <span className="badge">GPU 0/1 Existing vLLM Reuse</span>
          </div>
        </div>
        <div className="hero-summary panel">
          <h2>规划链路</h2>
          <div className="summary-line">
            <strong>本地工作台</strong>
            <span>录入批次、目标体重与时间窗</span>
          </div>
          <div className="summary-line">
            <strong>SSH 隧道</strong>
            <span>转发到 `gpu6000:8797`</span>
          </div>
          <div className="summary-line">
            <strong>远端规划后端</strong>
            <span>读取 CSV、执行生长预测、生成结构化计划</span>
          </div>
        </div>
      </section>
      <section className="workspace">
        <div className="panel panel-glass">
          <h2>输入面板</h2>
          <PlanningWindowForm batches={batches} form={form} loading={loading} onChange={setForm} onSubmit={handleSubmit} />
          {error ? <p style={{ color: "#fb7185" }}>{error}</p> : null}
        </div>
        <div className="stack">
          {plan ? (
            <ProductionPlanView plan={plan} />
          ) : (
            <div className="panel panel-feature">
              <h2>结果区</h2>
              <p>选择批次并生成生产计划后，这里会展示当前状态、增长曲线和分周计划。</p>
            </div>
          )}
        </div>
        <div className="stack">
          {plan ? (
            <>
              <div className="panel panel-glass">
                <RiskCards plan={plan} />
              </div>
              <div className="panel panel-glass">
                <ActionItems plan={plan} />
              </div>
              <div className="panel panel-glass">
                <ChatPanel plan={plan} />
              </div>
              <div className="panel panel-glass">
                <DebugTracePanel plan={plan} />
              </div>
            </>
          ) : (
            <div className="panel panel-feature">
              <h2>解释与调试</h2>
              <p>计划生成后，这里会展示风险、行动项、解释文本和图执行路径。</p>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
