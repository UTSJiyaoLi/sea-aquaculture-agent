import { useEffect, useRef, useState } from 'react'
import { Fish, TrendingUp, Scale, AlertTriangle, Droplets, CalendarDays, Wheat } from 'lucide-react'

const capabilities = [
  {
    icon: TrendingUp,
    title: '生长预测',
    desc: '基于历史体测量数据与确定性生长模型，预测鱼群在规划窗口内的体重增长曲线。',
  },
  {
    icon: Scale,
    title: '生物量估算',
    desc: '结合养殖密度、存活率与个体体重，实时估算批次总生物量，辅助收获决策。',
  },
  {
    icon: Wheat,
    title: '投喂规划',
    desc: '根据生长阶段、水温与目标规格，智能制定每日投喂量与饲料配比方案。',
  },
  {
    icon: AlertTriangle,
    title: '风险评估',
    desc: '综合分析水质异常、死亡率波动与投喂偏差，输出风险等级与预警行动项。',
  },
]

export default function Capabilities() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)

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
          // CORE CAPABILITIES
        </p>

        {/* Heading */}
        <h2
          className={`font-display font-medium text-[28px] md:text-[32px] text-abyss-text mb-4 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.1s' }}
        >
          深远海养殖，智能规划
        </h2>

        <p
          className={`text-abyss-text-dim max-w-[600px] mb-12 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'
          }`}
          style={{ transitionDelay: '0.15s' }}
        >
          基于 FastAPI + LangGraph 工作流，读取批次数据、水质历史与投喂记录，生成结构化生产计划
        </p>

        {/* Cards grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {capabilities.map((cap, i) => {
            const Icon = cap.icon
            return (
              <div
                key={cap.title}
                className={`group relative rounded-[20px] border border-abyss-cyan/10 bg-[rgba(10,25,50,0.3)] p-8 md:p-10 transition-all duration-500 hover:border-abyss-cyan/30 hover:-translate-y-1 hover:shadow-[0_10px_40px_rgba(0,212,255,0.1)] ${
                  visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
                }`}
                style={{ transitionDelay: `${0.2 + i * 0.1}s` }}
              >
                <div className="w-12 h-12 rounded-xl bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center mb-5 group-hover:bg-abyss-cyan/15 group-hover:border-abyss-cyan/30 transition-all duration-300">
                  <Icon className="w-6 h-6 text-abyss-cyan" />
                </div>
                <h3 className="font-display font-medium text-xl text-abyss-text mb-3">
                  {cap.title}
                </h3>
                <p className="text-abyss-text-dim leading-relaxed">{cap.desc}</p>
              </div>
            )
          })}
        </div>

        {/* Planning pipeline summary */}
        <div
          className={`mt-16 rounded-[20px] border border-abyss-cyan/10 bg-[rgba(10,25,50,0.3)] p-8 md:p-10 transition-all duration-700 ${
            visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
          style={{ transitionDelay: '0.6s' }}
        >
          <h3 className="font-display font-medium text-lg text-abyss-text mb-6">规划链路</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-lg bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center shrink-0 mt-0.5">
                <Fish className="w-5 h-5 text-abyss-cyan" />
              </div>
              <div>
                <p className="text-abyss-text font-medium text-sm mb-1">批次建档</p>
                <p className="text-abyss-text-dim text-xs leading-relaxed">
                  读取 batch_id、species、cage_id、当前均重等基础档案
                </p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-lg bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center shrink-0 mt-0.5">
                <Droplets className="w-5 h-5 text-abyss-cyan" />
              </div>
              <div>
                <p className="text-abyss-text font-medium text-sm mb-1">水质与生长分析</p>
                <p className="text-abyss-text-dim text-xs leading-relaxed">
                  结合水质历史与体测量数据，执行生长预测与生物量估算
                </p>
              </div>
            </div>
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-lg bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center shrink-0 mt-0.5">
                <CalendarDays className="w-5 h-5 text-abyss-cyan" />
              </div>
              <div>
                <p className="text-abyss-text font-medium text-sm mb-1">结构化计划输出</p>
                <p className="text-abyss-text-dim text-xs leading-relaxed">
                  生成投喂计划、风险卡片、行动项与调试追踪路径
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
