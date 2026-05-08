import { useEffect, useState } from 'react'
import { ChevronDown, Fish, Waves, Anchor } from 'lucide-react'

const particles = Array.from({ length: 20 }, (_, i) => ({
  id: i,
  left: `${Math.random() * 100}%`,
  size: Math.random() * 3 + 1,
  duration: Math.random() * 12 + 8,
  delay: Math.random() * 10,
  opacity: Math.random() * 0.4 + 0.2,
}))

export default function Hero() {
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const timer = setTimeout(() => setLoaded(true), 100)
    return () => clearTimeout(timer)
  }, [])

  const scrollToWorkSpace = () => {
    const el = document.getElementById('workspace-section')
    if (el) el.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className="relative w-full min-h-screen overflow-hidden">
      {/* Background image */}
      <div
        className="absolute inset-0 bg-cover bg-center bg-no-repeat"
        style={{
          backgroundImage: "url('/background.png')",
          filter: 'brightness(0.85) saturate(1.1)',
        }}
      />

      {/* Gradient overlay */}
      <div
        className="absolute inset-0"
        style={{
          background: 'linear-gradient(to bottom, rgba(5,10,20,0.3) 0%, rgba(5,10,20,0.6) 60%, #050a14 100%)',
        }}
      />

      {/* Pulse glow overlay */}
      <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div
          className="w-[800px] h-[800px] rounded-full animate-pulse-glow"
          style={{
            background: 'radial-gradient(circle at center, rgba(0,212,255,0.08) 0%, transparent 70%)',
          }}
        />
      </div>

      {/* Floating particles */}
      {particles.map((p) => (
        <div
          key={p.id}
          className="absolute rounded-full animate-float-up pointer-events-none"
          style={{
            left: p.left,
            width: p.size,
            height: p.size,
            backgroundColor: '#00d4ff',
            opacity: p.opacity,
            animationDuration: `${p.duration}s`,
            animationDelay: `${p.delay}s`,
          }}
        />
      ))}

      {/* Content */}
      <div className="relative z-10 flex flex-col items-center justify-center min-h-screen px-6 pt-20 pb-32">
        {/* Top badges */}
        <div
          className={`flex items-center gap-3 mb-6 transition-all duration-500 ${
            loaded ? 'opacity-100 scale-100' : 'opacity-0 scale-95'
          }`}
          style={{ transitionDelay: '0.2s' }}
        >
          <span className="flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-abyss-cyan/20 bg-abyss-cyan/10 text-abyss-cyan text-xs font-mono tracking-wider">
            <Anchor className="w-3.5 h-3.5" />
            深远海养殖
          </span>
          <span className="relative flex items-center gap-1.5 px-3 py-1.5 rounded-full border border-abyss-cyan/20 bg-abyss-cyan/10 text-abyss-cyan text-xs font-mono tracking-wider">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-abyss-cyan opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-abyss-cyan" />
            </span>
            规划中
          </span>
        </div>

        {/* Main title */}
        <h1
          className={`font-display font-bold text-[48px] md:text-[64px] text-abyss-text tracking-tight text-center transition-all duration-[800ms] ${
            loaded ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
          }`}
          style={{
            transitionDelay: '0.4s',
            textShadow: '0 0 40px rgba(0,212,255,0.3)',
            letterSpacing: '-0.02em',
          }}
        >
          深远海养殖
          <br />
          <span className="text-abyss-cyan">生产规划智能体</span>
        </h1>

        {/* Subtitle */}
        <p
          className={`mt-5 text-lg md:text-xl text-abyss-text-dim text-center max-w-[580px] leading-relaxed transition-all duration-700 ${
            loaded ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-5'
          }`}
          style={{ transitionDelay: '0.6s' }}
        >
          读取批次数据、水质历史、体测量与投喂记录，基于 LangGraph 工作流生成结构化生产计划
        </p>

        {/* Stats row */}
        <div
          className={`flex flex-wrap justify-center gap-8 md:gap-12 mt-10 transition-all duration-700 ${
            loaded ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-5'
          }`}
          style={{ transitionDelay: '0.75s' }}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center">
              <Fish className="w-5 h-5 text-abyss-cyan" />
            </div>
            <div>
              <p className="text-abyss-text font-medium text-sm">批次中心</p>
              <p className="text-abyss-text-dim text-xs">Batch-Centric Planning</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-abyss-cyan/10 border border-abyss-cyan/20 flex items-center justify-center">
              <Waves className="w-5 h-5 text-abyss-cyan" />
            </div>
            <div>
              <p className="text-abyss-text font-medium text-sm">生长预测</p>
              <p className="text-abyss-text-dim text-xs">Deterministic Model</p>
            </div>
          </div>
        </div>

        {/* CTA Button */}
        <button
          onClick={scrollToWorkSpace}
          className={`mt-12 px-8 py-3.5 rounded-full font-medium text-abyss-text border border-abyss-cyan/30 bg-abyss-cyan/10 backdrop-blur-md transition-all duration-500 hover:bg-abyss-cyan/20 hover:border-abyss-cyan/50 hover:shadow-cyan-sm ${
            loaded ? 'opacity-100' : 'opacity-0'
          }`}
          style={{ transitionDelay: '0.9s' }}
        >
          进入工作台
        </button>

        {/* Scroll indicator */}
        <div
          className={`absolute bottom-10 flex flex-col items-center gap-2 transition-all duration-500 ${
            loaded ? 'opacity-100' : 'opacity-0'
          }`}
          style={{ transitionDelay: '1.3s' }}
        >
          <span className="text-xs text-abyss-text-dim font-mono tracking-wider">SCROLL</span>
          <ChevronDown className="w-5 h-5 text-abyss-cyan animate-bounce-chevron" />
        </div>
      </div>
    </section>
  )
}
