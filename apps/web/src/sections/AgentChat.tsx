import { useEffect, useRef, useState } from 'react'
import { Send, Bot, User, Loader2 } from 'lucide-react'

interface Message {
  role: 'user' | 'agent'
  content: string
  timestamp: Date
}

const INITIAL_MESSAGES: Message[] = [
  {
    role: 'agent',
    content: '你好！我是深远海养殖生产规划助手。你可以问我关于批次规划、生长预测、投喂策略或风险评估的问题。',
    timestamp: new Date(),
  },
]

const SUGGESTIONS = [
  '为 BATCH_A 生成 30 天生产计划',
  '分析 BATCH_B 的死亡风险',
  '预测 BATCH_C 达到目标体重的时间',
  '当前水温对投喂量有什么影响？',
]

export default function AgentChat() {
  const sectionRef = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)
  const [messages, setMessages] = useState<Message[]>(INITIAL_MESSAGES)
  const [inputValue, setInputValue] = useState('')
  const [isTyping, setIsTyping] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)

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

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSend = async () => {
    if (!inputValue.trim()) return

    const userMsg: Message = {
      role: 'user',
      content: inputValue.trim(),
      timestamp: new Date(),
    }

    setMessages(prev => [...prev, userMsg])
    setInputValue('')
    setIsTyping(true)

    // Simulate agent response (in real deployment, call POST /api/agent/chat)
    setTimeout(() => {
      const responses: Record<string, string> = {
        'BATCH_A': '已收到 BATCH_A 的规划请求。当前均重 420g，目标 600g，预计需要约 120 天。建议逐步增加投喂量，每周增幅不超过 15%，并每 14 天采样一次。',
        'BATCH_B': 'BATCH_B 当前均重 380g，距离目标 550g 还有 170g。生长曲线显示正常，但需注意秋季水温下降可能带来的摄食减缓风险。',
        '风险': '基于近期水质数据，溶解氧稳定在 7.2 mg/L，氨氮 < 0.02 mg/L，风险等级：低。建议维持当前投喂策略。',
        '水温': '当前平均水温 14.5°C，处于大西洋鲑最适生长区间（12-16°C）。建议维持现有投喂量，预计 FCR 约为 1.15。',
      }

      let responseText = '收到你的问题。在实际部署环境中，我会调用后端的 LangGraph 工作流来为你生成详细的结构化生产计划。你可以通过 /api/agent/chat 接口与我交互。'

      for (const [key, value] of Object.entries(responses)) {
        if (userMsg.content.includes(key)) {
          responseText = value
          break
        }
      }

      const agentMsg: Message = {
        role: 'agent',
        content: responseText,
        timestamp: new Date(),
      }
      setMessages(prev => [...prev, agentMsg])
      setIsTyping(false)
    }, 1500)
  }

  const handleSuggestion = (text: string) => {
    setInputValue(text)
  }

  return (
    <section
      ref={sectionRef}
      className="relative w-full bg-[#050a14] py-[100px] px-6"
    >
      <div
        className={`max-w-[900px] mx-auto transition-all duration-700 ${
          visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'
        }`}
      >
        {/* Section label */}
        <p className="font-mono text-sm text-abyss-cyan tracking-wider mb-3">
          // AGENT CHAT
        </p>

        <h2 className="font-display font-medium text-[28px] md:text-[32px] text-abyss-text mb-4">
          与养殖规划助手对话
        </h2>

        <p className="text-abyss-text-dim mb-10">
          通过自然语言与 Agent 交互，获取生产规划、风险分析与行动建议。后端接口：POST /api/agent/chat
        </p>

        {/* Chat container */}
        <div className="rounded-[20px] border border-abyss-cyan/15 bg-[rgba(10,25,50,0.4)] backdrop-blur-xl overflow-hidden">
          {/* Messages area */}
          <div className="h-[420px] overflow-y-auto p-6 space-y-5">
            {messages.map((msg, i) => (
              <div
                key={i}
                className={`flex gap-3 ${msg.role === 'user' ? 'flex-row-reverse' : ''}`}
              >
                <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                  msg.role === 'agent'
                    ? 'bg-abyss-cyan/15 border border-abyss-cyan/30'
                    : 'bg-[rgba(255,255,255,0.08)] border border-[rgba(255,255,255,0.12)]'
                }`}>
                  {msg.role === 'agent' ? (
                    <Bot className="w-4 h-4 text-abyss-cyan" />
                  ) : (
                    <User className="w-4 h-4 text-abyss-text-dim" />
                  )}
                </div>
                <div className={`max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-relaxed ${
                  msg.role === 'agent'
                    ? 'bg-[rgba(0,212,255,0.08)] border border-abyss-cyan/15 text-abyss-text'
                    : 'bg-[rgba(255,255,255,0.06)] border border-[rgba(255,255,255,0.08)] text-abyss-text'
                }`}>
                  {msg.content}
                </div>
              </div>
            ))}

            {isTyping && (
              <div className="flex gap-3">
                <div className="w-8 h-8 rounded-full bg-abyss-cyan/15 border border-abyss-cyan/30 flex items-center justify-center shrink-0">
                  <Bot className="w-4 h-4 text-abyss-cyan" />
                </div>
                <div className="bg-[rgba(0,212,255,0.08)] border border-abyss-cyan/15 rounded-2xl px-4 py-3">
                  <div className="flex items-center gap-1.5">
                    <Loader2 className="w-3.5 h-3.5 text-abyss-cyan animate-spin" />
                    <span className="text-sm text-abyss-text-dim">正在规划...</span>
                  </div>
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          {/* Suggestions */}
          <div className="px-6 pb-2">
            <div className="flex flex-wrap gap-2">
              {SUGGESTIONS.map((suggestion) => (
                <button
                  key={suggestion}
                  onClick={() => handleSuggestion(suggestion)}
                  className="px-3 py-1.5 rounded-full border border-abyss-cyan/15 text-abyss-text-dim text-xs hover:bg-abyss-cyan/10 hover:text-abyss-cyan hover:border-abyss-cyan/30 transition-all duration-300"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>

          {/* Input area */}
          <div className="p-4 border-t border-abyss-cyan/10">
            <div className="flex items-center gap-3">
              <input
                type="text"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                placeholder="输入你的问题，例如：为 BATCH_A 生成 30 天生产计划..."
                className="flex-1 bg-[rgba(5,10,20,0.5)] border border-abyss-cyan/15 rounded-xl px-4 py-3 text-sm text-abyss-text placeholder-abyss-text-dim outline-none focus:border-abyss-cyan/40 transition-colors"
              />
              <button
                onClick={handleSend}
                disabled={!inputValue.trim() || isTyping}
                className="w-10 h-10 rounded-full bg-abyss-cyan/15 border border-abyss-cyan/30 flex items-center justify-center text-abyss-cyan hover:bg-abyss-cyan/25 hover:border-abyss-cyan/50 transition-all duration-300 disabled:opacity-40 disabled:cursor-not-allowed shrink-0"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
