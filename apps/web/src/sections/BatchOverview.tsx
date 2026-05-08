import { useEffect, useRef, useState } from 'react'
import { Fish, Scale, Target, Calendar, ChevronRight, Loader2 } from 'lucide-react'

// Mock batch data aligned with the repo's backend schema
const MOCK_BATCHES = [
  {
    batch_id: "BATCH_A",
    cage_id: "CAGE_01",
    species: "大西洋鲑",
    current_avg_weight_g: 420,
    estimated_biomass_kg: 8500,
    target_weight_g: 600,
    target_date: "2026-10-30",
  },
  {
    batch_id: "BATCH_B",
    cage_id: "CAGE_02",
    species: "大西洋鲑",
    current_avg_weight_g: 380,
    estimated_biomass_kg: 7200,
    target_weight_g: 550,
    target_date: "2026-11-15",
  },
  {
    batch_id: "BATCH_C",
    cage_id: "CAGE_03",
    species: "虹鳟",
    current_avg_weight_g: 290,
    estimated_biomass_kg: 5400,
    target_weight_g: 450,
    target_date: "2026-09-20",
  },
]

export default function BatchOverview() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)
  const [loading, setLoading] = useState(true)
  const [batches, setBatches] = useState<typeof MOCK_BATCHES>([])
  const [selectedBatch, setSelectedBatch] = useState<string | null>(null)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true)
          observer.disconnect()
        }
      },
      { threshold: 0.15 }
    )
    if (sectionRef.current) observer.observe(sectionRef.current)
    return () => observer.disconnect()
  }, [])

  // Simulate fetching from /api/batches
  useEffect(() => {
    if (!visible) return
    const timer = setTimeout(() => {
      setBatches(MOCK_BATCHES)
      setSelectedBatch(MOCK_BATCHES[0].batch_id)
      setLoading(false)
    }, 800)
    return () => clearTimeout(timer)
  }, [visible])

  const selected = batches.find(b => b.batch_id === selectedBatch)

  return (
    <section
      id="workspace-section"
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
          // BATCH OVERVIEW
        </p>

        <h2
          className={`font-display font-medium text-[28px] md:text-[32px] text-abyss-text mb-4 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.1s' }}
        >
          批次概览
        </h2>

        <p
          className={`text-abyss-text-dim max-w-[600px] mb-10 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.15s' }}
        >
          选择养殖批次，查看当前状态与目标规格。实际部署时从远端 FastAPI 的 /api/batches 接口实时拉取
        </p>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="w-8 h-8 text-abyss-cyan animate-spin" />
            <span className="ml-3 text-abyss-text-dim">正在连接远端规划服务...</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
            {/* Batch list */}
            <div className="lg:col-span-1 space-y-3">
              {batches.map((batch, i) => (
                <button
                  key={batch.batch_id}
                  onClick={() => setSelectedBatch(batch.batch_id)}
                  className={`w-full text-left rounded-[16px] border p-5 transition-all duration-300 ${
                    selectedBatch === batch.batch_id
                      ? 'border-abyss-cyan/40 bg-[rgba(10,25,50,0.5)] shadow-[0_0_20px_rgba(0,212,255,0.1)]'
                      : 'border-abyss-cyan/10 bg-[rgba(10,25,50,0.3)] hover:border-abyss-cyan/25 hover:bg-[rgba(10,25,50,0.4)]'
                  } ${visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}
                  style={{ transitionDelay: `${0.2 + i * 0.08}s` }}
                >
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-mono text-sm text-abyss-cyan">{batch.batch_id}</span>
                    <ChevronRight className={`w-4 h-4 transition-transform ${selectedBatch === batch.batch_id ? 'text-abyss-cyan translate-x-0' : 'text-abyss-text-dim -translate-x-1'}`} />
                  </div>
                  <p className="text-abyss-text font-medium">{batch.species}</p>
                  <p className="text-abyss-text-dim text-sm mt-1">{batch.cage_id}</p>
                </button>
              ))}
            </div>

            {/* Batch detail */}
            <div className="lg:col-span-2">
              {selected && (
                <div className="rounded-[20px] border border-abyss-cyan/15 bg-[rgba(10,25,50,0.4)] backdrop-blur-xl p-8">
                  <div className="flex items-center gap-3 mb-8">
                    <div className="w-12 h-12 rounded-xl bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center">
                      <Fish className="w-6 h-6 text-abyss-cyan" />
                    </div>
                    <div>
                      <h3 className="font-display font-medium text-xl text-abyss-text">{selected.batch_id}</h3>
                      <p className="text-abyss-text-dim text-sm">{selected.species} · {selected.cage_id}</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div className="rounded-xl border border-abyss-cyan/10 bg-[rgba(5,10,20,0.4)] p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <Scale className="w-4 h-4 text-abyss-cyan" />
                        <span className="text-xs text-abyss-text-dim">当前均重</span>
                      </div>
                      <p className="text-abyss-text font-display font-medium text-lg">{selected.current_avg_weight_g} <span className="text-sm text-abyss-text-dim">g</span></p>
                    </div>

                    <div className="rounded-xl border border-abyss-cyan/10 bg-[rgba(5,10,20,0.4)] p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <Fish className="w-4 h-4 text-abyss-cyan" />
                        <span className="text-xs text-abyss-text-dim">预估生物量</span>
                      </div>
                      <p className="text-abyss-text font-display font-medium text-lg">{selected.estimated_biomass_kg.toLocaleString()} <span className="text-sm text-abyss-text-dim">kg</span></p>
                    </div>

                    <div className="rounded-xl border border-abyss-cyan/10 bg-[rgba(5,10,20,0.4)] p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <Target className="w-4 h-4 text-abyss-cyan" />
                        <span className="text-xs text-abyss-text-dim">目标体重</span>
                      </div>
                      <p className="text-abyss-text font-display font-medium text-lg">{selected.target_weight_g} <span className="text-sm text-abyss-text-dim">g</span></p>
                    </div>

                    <div className="rounded-xl border border-abyss-cyan/10 bg-[rgba(5,10,20,0.4)] p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <Calendar className="w-4 h-4 text-abyss-cyan" />
                        <span className="text-xs text-abyss-text-dim">目标日期</span>
                      </div>
                      <p className="text-abyss-text font-display font-medium text-lg">{selected.target_date}</p>
                    </div>
                  </div>

                  {/* Progress bar */}
                  <div className="mt-8">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-sm text-abyss-text-dim">生长进度</span>
                      <span className="text-sm text-abyss-cyan font-mono">
                        {Math.round((selected.current_avg_weight_g / selected.target_weight_g) * 100)}%
                      </span>
                    </div>
                    <div className="h-2 rounded-full bg-[rgba(0,212,255,0.1)] overflow-hidden">
                      <div
                        className="h-full rounded-full bg-gradient-to-r from-abyss-cyan/60 to-abyss-cyan transition-all duration-1000"
                        style={{ width: `${(selected.current_avg_weight_g / selected.target_weight_g) * 100}%` }}
                      />
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
