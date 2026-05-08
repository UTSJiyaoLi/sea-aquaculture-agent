import Hero from './sections/Hero'
import Capabilities from './sections/Capabilities'
import BatchOverview from './sections/BatchOverview'
import PlanningForm from './sections/PlanningForm'
import AgentChat from './sections/AgentChat'
import Footer from './sections/Footer'

function App() {
  return (
    <div className="min-h-screen bg-[#050a14] overflow-x-hidden">
      <Hero />
      <Capabilities />
      <BatchOverview />
      <PlanningForm />
      <AgentChat />
      <Footer />
    </div>
  )
}

export default App
