export default function Footer() {
  return (
    <footer className="w-full bg-[#050a14] border-t border-abyss-cyan/10 py-10 px-6">
      <div className="max-w-[1200px] mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span
            className="font-display font-medium text-xl text-abyss-cyan"
            style={{ textShadow: '0 0 20px rgba(0,212,255,0.2)' }}
          >
            Sea Aquaculture Agent
          </span>
          <span className="text-xs text-abyss-text-dim border border-abyss-cyan/15 px-2 py-0.5 rounded-md font-mono">
            v0.1.0
          </span>
        </div>
        <div className="flex items-center gap-6 text-sm text-abyss-text-dim">
          <span>FastAPI + LangGraph</span>
          <span>·</span>
          <span>Remote Backend</span>
          <span>·</span>
          <span>gpu6000</span>
        </div>
        <p className="text-xs text-abyss-text-dim opacity-60">
          © 2025 UTS Jiyao Li. All rights reserved.
        </p>
      </div>
    </footer>
  )
}
