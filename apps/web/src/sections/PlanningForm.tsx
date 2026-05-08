import { useEffect, useRef, useState } from 'react'
import { Play, Calendar, Target, Wheat, Shield, Clock, Loader2, CheckCircle2 } from 'lucide-react'

export default function PlanningForm() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<any>(null)
  const [form, setForm] = useState({
    batch_id: 'BATCH_A',
    horizon_days: 30,
    target_weight_g: 600,
    target_date: '2026-10-30',
    user_goal: '希望控制风险，并尽量按目标规格稳步推进。',
  })

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true)
          observer.disconnect()
        }
      },
      { threshold: 0.1 }
    )
    if (sectionRef.current) observer.observe(sectionRef.current)
    return () => observer.disconnect()
  }, [])

  const handleSubmit = async () => {
    setLoading(true)
    // Simulate calling POST /api/production/plan
    setTimeout(() => {
      setResult({
        status: 'success',
        batch_id: form.batch_id,
        horizon_days: form.horizon_days,
        weekly_plan: [
          { week: 1, avg_weight_g: 435, feed_kg: 2100, risk: '低' },
          { week: 2, avg_weight_g: 452, feed_kg: 2250, risk: '低' },
          { week: 3, avg_weight_g: 470, feed_kg: 2400, risk: '中' },
          { week: 4, avg_weight_g: 490, feed_kg: 2550, risk: '低' },
        ],
        risk_items: [
          { level: 'medium', title: '第三周水温波动', desc: '预计第三周水温可能下降至 11°C，建议提前调整投喂时间。' },
          { level: 'low', title: '生长速度略低于预期', desc: '当前 FCR 1.18，略高于目标 1.15，建议检查饲料品质。' },
        ],
        action_items: [
          '每周一上午 9:00 执行体测量采样',
          '第三周起将日投喂次数从 2 次调整为 3 次',
          '密切监测溶解氧，保持 > 6.5 mg/L',
        ],
        debug_trace: ['load_batch', 'water_quality_check', 'growth_projection', 'biomass_estimation', 'feeding_plan', 'risk_assessment', 'report_generation'],
      })
      setLoading(false)
    }, 2000)
  }

  return (
    <section
      ref={sectionRef}
      className="relative w-full bg-[#050a14] py-[100px] px-6"
    >
      <div className="max-w-[1200px] mx-auto">
        {/* Section label */}
        <p
          className={`font-mono text-sm text-abyss-cyan tracking-wider mb-3 transition-all duration-500 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
        >
          // PRODUCTION PLANNING
        </p>

        <h2
          className={`font-display font-medium text-[28px] md:text-[32px] text-abyss-text mb-4 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.1s' }}
        >
          生产规划演示
        </h2>

        <p
          className={`text-abyss-text-dim max-w-[600px] mb-10 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.15s' }}
        >
          填写规划参数，模拟调用后端 /api/production/plan 接口，生成结构化生产计划
        </p>

        <div className="grid grid-cols-1 lg:grid-cols-5 gap-5">
          {/* Input panel */}
          <div
            className={`lg:col-span-2 rounded-[20px] border border-abyss-cyan/15 bg-[rgba(10,25,50,0.4)] backdrop-blur-xl p-6 transition-all duration-700 ${
              visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
            }`}
            style={{ transitionDelay: '0.2s' }}
          >
            <h3 className="font-display font-medium text-lg text-abyss-text mb-6">规划参数</h3>

            <div className="space-y-4">
              <div>
                <label className="flex items-center gap-2 text-sm text-abyss-text-dim mb-2">
                  <Target className="w-4 h-4 text-abyss-cyan" />
                  批次 ID
                </label>
                <select
                  value={form.batch_id}
                  onChange={(e) => setForm({ ...form, batch_id: e.target.value })}
                  className="w-full bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-2.5 text-sm text-abyss-text outline-none focus:border-abyss-cyan/40 transition-colors"
                >
                  <option value="BATCH_A">BATCH_A</option>
                  <option value="BATCH_B">BATCH_B</option>
                  <option value="BATCH_C">BATCH_C</option>
                </select>
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm text-abyss-text-dim mb-2">
                  <Clock className="w-4 h-4 text-abyss-cyan" />
                  规划周期（天）
                </label>
                <input
                  type="number"
                  value={form.horizon_days}
                  onChange={(e) => setForm({ ...form, horizon_days: Number(e.target.value) })}
                  className="w-full bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-2.5 text-sm text-abyss-text outline-none focus:border-abyss-cyan/40 transition-colors"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm text-abyss-text-dim mb-2">
                  <Target className="w-4 h-4 text-abyss-cyan" />
                  目标体重（g）
                </label>
                <input
                  type="number"
                  value={form.target_weight_g}
                  onChange={(e) => setForm({ ...form, target_weight_g: Number(e.target.value) })}
                  className="w-full bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-2.5 text-sm text-abyss-text outline-none focus:border-abyss-cyan/40 transition-colors"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm text-abyss-text-dim mb-2">
                  <Calendar className="w-4 h-4 text-abyss-cyan" />
                  目标日期
                </label>
                <input
                  type="date"
                  value={form.target_date}
                  onChange={(e) => setForm({ ...form, target_date: e.target.value })}
                  className="w-full bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-2.5 text-sm text-abyss-text outline-none focus:border-abyss-cyan/40 transition-colors"
                />
              </div>

              <div>
                <label className="flex items-center gap-2 text-sm text-abyss-text-dim mb-2">
                  <Wheat className="w-4 h-4 text-abyss-cyan" />
                  用户目标
                </label>
                <textarea
                  value={form.user_goal}
                  onChange={(e) => setForm({ ...form, user_goal: e.target.value })}
                  rows={3}
                  className="w-full bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-2.5 text-sm text-abyss-text outline-none focus:border-abyss-cyan/40 transition-colors resize-none"
                />
              </div>

              <button
                onClick={handleSubmit}
                disabled={loading}
                className="w-full mt-2 flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-abyss-cyan/15 border border-abyss-cyan/30 text-abyss-cyan font-medium hover:bg-abyss-cyan/25 hover:border-abyss-cyan/50 transition-all duration-300 disabled:opacity-50"
              >
                {loading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    规划执行中...
                  </>
                ) : (
                  <>
                    <Play className="w-4 h-4" />
                    生成生产计划
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Result panel */}
          <div
            className={`lg:col-span-3 rounded-[20px] border border-abyss-cyan/15 bg-[rgba(10,25,50,0.4)] backdrop-blur-xl p-6 transition-all duration-700 ${
              visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
            }`}
            style={{ transitionDelay: '0.3s' }}
          >
            <h3 className="font-display font-medium text-lg text-abyss-text mb-6">规划结果</h3>

            {!result && !loading && (
              <div className="flex flex-col items-center justify-center h-[300px] text-abyss-text-dim">
                <Shield className="w-12 h-12 mb-4 opacity-30" />
                <p>填写参数并点击「生成生产计划」查看结果</p>
                <p className="text-xs mt-2 opacity-60">后端接口：POST /api/production/plan</p>
              </div>
            )}

            {loading && (
              <div className="flex flex-col items-center justify-center h-[300px]">
                <Loader2 className="w-10 h-10 text-abyss-cyan animate-spin mb-4" />
                <p className="text-abyss-text-dim">LangGraph 工作流执行中...</p>
                <div className="mt-4 space-y-1 text-xs text-abyss-text-dim font-mono">
                  <p>→ load_batch</p>
                  <p>→ water_quality_check</p>
                  <p>→ growth_projection...</p>
                </div>
              </div>
            )}

            {result && (
              <div className="space-y-5">
                {/* Weekly plan table */}
                <div>
                  <h4 className="text-sm text-abyss-text-dim mb-3">分周计划</h4>
                  <div className="rounded-xl border border-abyss-cyan/10 overflow-hidden">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="bg-[rgba(0,212,255,0.06)] border-b border-abyss-cyan/10">
                          <th className="px-4 py-2.5 text-left text-abyss-text-dim font-medium">周次</th>
                          <th className="px-4 py-2.5 text-left text-abyss-text-dim font-medium">均重 (g)</th>
                          <th className="px-4 py-2.5 text-left text-abyss-text-dim font-medium">投喂量 (kg)</th>
                          <th className="px-4 py-2.5 text-left text-abyss-text-dim font-medium">风险</th>
                        </tr>
                      </thead>
                      <tbody>
                        {result.weekly_plan.map((week: any, i: number) => (
                          <tr key={i} className="border-b border-abyss-cyan/5 last:border-0">
                            <td className="px-4 py-2.5 text-abyss-text font-mono">{week.week}</td>
                            <td className="px-4 py-2.5 text-abyss-text">{week.avg_weight_g}</td>
                            <td className="px-4 py-2.5 text-abyss-text">{week.feed_kg.toLocaleString()}</td>
                            <td className="px-4 py-2.5">
                              <span className={`px-2 py-0.5 rounded-full text-xs font-mono ${
                                week.risk === '低'
                                  ? 'bg-green-500/10 text-green-400 border border-green-500/20'
                                  : week.risk === '中'
                                  ? 'bg-yellow-500/10 text-yellow-400 border border-yellow-500/20'
                                  : 'bg-red-500/10 text-red-400 border border-red-500/20'
                              }`}>
                                {week.risk}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>

                {/* Risk cards */}
                <div>
                  <h4 className="text-sm text-abyss-text-dim mb-3">风险预警</h4>
                  <div className="space-y-2">
                    {result.risk_items.map((risk: any, i: number) => (
                      <div
                        key={i}
                        className={`rounded-xl border p-3 ${
                          risk.level === 'medium'
                            ? 'border-yellow-500/20 bg-yellow-500/5'
                            : 'border-abyss-cyan/10 bg-[rgba(5,10,20,0.3)]'
                        }`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <span className={`w-2 h-2 rounded-full ${
                            risk.level === 'medium' ? 'bg-yellow-400' : 'bg-abyss-cyan'
                          }`} />
                          <span className="text-sm text-abyss-text font-medium">{risk.title}</span>
                        </div>
                        <p className="text-xs text-abyss-text-dim pl-4">{risk.desc}</p>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Action items */}
                <div>
                  <h4 className="text-sm text-abyss-text-dim mb-3">行动项</h4>
                  <div className="space-y-2">
                    {result.action_items.map((action: string, i: number) => (
                      <div key={i} className="flex items-start gap-2 text-sm text-abyss-text">
                        <CheckCircle2 className="w-4 h-4 text-abyss-cyan shrink-0 mt-0.5" />
                        <span>{action}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Debug trace */}
                <div>
                  <h4 className="text-sm text-abyss-text-dim mb-3">执行路径</h4>
                  <div className="flex flex-wrap gap-2">
                    {result.debug_trace.map((node: string, i: number) => (
                      <span
                        key={i}
                        className="px-2.5 py-1 rounded-lg bg-abyss-cyan/8 border border-abyss-cyan/15 text-xs text-abyss-cyan font-mono"
                      >
                        {node}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}
