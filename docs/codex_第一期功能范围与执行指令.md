# Codex 执行指令：第一期功能范围与项目实现计划

> 项目：深远海养殖前期任意时段生产规划智能体  
> 目标：先做一个能运行、能演示、结构清楚、方便后续接入真实模型和水质分析工具的 V0/V1 工程底座。  
> 关键原则：第一期只解决“一个养殖批次在任意前期时间窗内怎么养”的问题，不做完整销售规划，不把复杂 R/MFPCA 阻塞在主链路里。

---

## 0. 给 Codex 的一句话目标

请实现一个 **FastAPI + LangGraph + Next.js** 的深远海养殖前期生产规划智能体。  
它以 **养殖批次 Batch** 为核心，支持用户输入 `batch_id`、未来天数或任意时间窗，读取 demo 批次、水质、体测、投喂、死亡数据，调用生长预测与风险规则，输出结构化生产计划 JSON，并在本地前端展示。

第一期必须保证：

```text
本地前端输入 batch_id + 时间窗
  ↓ SSH 隧道
远端 FastAPI
  ↓ LangGraph 工作流
读取 demo 批次/水质/体测/投喂/死亡数据
  ↓ mock 或可切换的生长预测工具
生成任意时间窗生产计划 JSON
  ↓
本地前端结构化展示当前状态、预测曲线、分周计划、风险和行动项
```

---

## 1. 第一期功能边界

### 1.1 第一期必须实现的功能

第一期叫：

```text
V1：前期任意时段生产规划智能体
```

必须实现 8 类能力。

#### 功能 1：项目工程骨架

建立一个可以长期扩展的工程结构：

```text
aquaculture-agent/
├── AGENTS.md
├── README.md
├── .env.example
├── requirements.txt
├── pyproject.toml
├── backend/
├── apps/web/
├── model_tools/
├── deploy/
├── docs/
└── scripts/
```

要求：

```text
1. 后端使用 FastAPI + LangGraph + Pydantic。
2. 前端使用 Next.js + TypeScript。
3. 数据层第一期使用 CSV demo 数据。
4. 所有端口、路径、模型开关写入 .env。
5. 必须提供 pytest 测试、smoke test、部署脚本。
6. 必须提供 AGENTS.md，给 Codex 保存项目规则和执行约束。
```

---

#### 功能 2：批次画像 Batch Profile

第一期的核心对象不是水质指标，也不是单个模型，而是：

```text
养殖批次 Batch / 生物资产 Digital Fish Asset
```

必须实现：

```text
GET /api/batches
GET /api/batches/{batch_id}/profile
```

批次画像至少包含：

```json
{
  "batch_id": "BATCH_A",
  "cage_id": "CAGE_03",
  "species": "large_yellow_croaker",
  "stocking_date": "2026-04-01",
  "initial_count": 65000,
  "initial_avg_weight_g": 10,
  "initial_avg_length_cm": 8.5,
  "current_estimated_count": 63000,
  "current_avg_weight_g": 120.5,
  "current_avg_length_cm": 18.2,
  "estimated_biomass_kg": 7591.5,
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "latest_measurement_date": "2026-06-01"
}
```

计算规则：

```text
current_avg_weight_g = 最新体测记录的 avg_weight_g
current_avg_length_cm = 最新体测记录的 avg_length_cm
current_estimated_count = batch.current_estimated_count，如果没有则用 initial_count - 累计死亡数量
estimated_biomass_kg = current_avg_weight_g * current_estimated_count / 1000
```

---

#### 功能 3：任意时间窗规划

生产规划接口必须支持三种输入方式。

方式 A：未来天数

```json
{
  "batch_id": "BATCH_A",
  "horizon_days": 30,
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "use_llm": false
}
```

方式 B：指定日期范围

```json
{
  "batch_id": "BATCH_A",
  "planning_start": "2026-06-01",
  "planning_end": "2026-07-15",
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "use_llm": false
}
```

方式 C：目标规格倒推

```json
{
  "batch_id": "BATCH_A",
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "user_goal": "希望按 10 月底达到 600g，前期应该怎么安排",
  "use_llm": false
}
```

实现 `normalize_planning_window`，输出：

```json
{
  "mode": "future_plan",
  "start_date": "2026-06-01",
  "end_date": "2026-07-01",
  "horizon_days": 30
}
```

第一期至少支持：

```text
future_plan
current_to_future
target_backcast
```

`historical_review` 可以先保留 router 和状态位，不必做复杂复盘。

---

#### 功能 4：生产规划 LangGraph 主流程

实现：

```text
POST /api/production/plan
```

LangGraph 节点顺序：

```text
START
  ↓
parse_intent
  ↓
normalize_planning_window
  ↓
load_batch_context
  ↓
check_data_quality
  ↓
summarize_environment
  ↓
run_growth_projection
  ↓
estimate_biomass
  ↓
generate_feeding_plan
  ↓
assess_risk
  ↓
generate_action_items
  ↓
write_response
  ↓
END
```

要求：

```text
1. 每个节点独立文件。
2. 每个节点只做一件事。
3. 每个节点向 debug_trace 写入自己的名字。
4. 节点之间通过 AgentState 传递状态。
5. 所有核心业务逻辑在 tools/services 中，不要写在 prompt 里。
6. use_llm=false 时也必须完整生成计划。
```

---

#### 功能 5：工具层 Tools

第一期必须实现 7 个工具。

```text
DatabaseQueryTool
WaterQualityTool
GrowthModelTool
BiomassEstimationTool
FeedingPlanTool
RiskRuleTool
ReportWriterTool
```

##### 5.1 DatabaseQueryTool

职责：

```text
读取 demo CSV 数据。
```

接口：

```python
class DatabaseQueryTool:
    def list_batches(self) -> list[dict]: ...
    def get_batch(self, batch_id: str) -> dict: ...
    def get_body_measurements(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict]: ...
    def get_feeding_records(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict]: ...
    def get_mortality_records(self, batch_id: str, start: str | None = None, end: str | None = None) -> list[dict]: ...
```

##### 5.2 WaterQualityTool

职责：

```text
按 cage_id 和时间窗读取水质，并输出摘要。
```

接口：

```python
class WaterQualityTool:
    def get_history(self, cage_id: str, start: str | None = None, end: str | None = None) -> list[dict]: ...
    def summarize(self, records: list[dict]) -> dict: ...
```

摘要至少包含：

```json
{
  "avg_temperature_c": 24.3,
  "min_temperature_c": 22.9,
  "max_temperature_c": 26.1,
  "avg_do_mg_l": 7.2,
  "min_do_mg_l": 5.8,
  "avg_salinity_ppt": 29.7,
  "avg_ph": 8.05,
  "record_count": 42
}
```

##### 5.3 GrowthModelTool

第一期需要做两层：

```text
默认：MockGrowthModelAdapter
预留：PatentFishiGrowthEcoAdapter
```

不要直接把 `Patent_fishi.py` 原脚本整段塞进主流程。  
第一期先把接口设计好，并允许通过环境变量切换：

```bash
GROWTH_MODEL_BACKEND=mock
# 后续可改成：
GROWTH_MODEL_BACKEND=patent_fishi
```

统一接口：

```python
class GrowthModelTool:
    def predict(
        self,
        batch_profile: dict,
        environment_summary: dict,
        start_date: str,
        end_date: str,
        target_weight_g: float | None = None,
    ) -> dict: ...
```

输出：

```json
{
  "series": [
    {
      "date": "2026-06-01",
      "day_index": 0,
      "avg_weight_g": 120.5,
      "avg_length_cm": 18.2,
      "estimated_survival_count": 63000,
      "biomass_kg": 7591.5,
      "feed_recommendation_kg": 180.0
    }
  ],
  "estimated_target_date": "2026-10-21",
  "target_achievable": true,
  "model_name": "MockGrowthModelAdapter",
  "model_assumptions": []
}
```

Mock 模型用 Logistic：

```text
W_next = W + r * W * (1 - W / W_max)
```

修正因子：

```text
temperature_factor = exp(-k * (temperature - 25)^2)
do_factor = 1.0 if DO >= 6 else 0.85 if DO >= 5 else 0.65
```

##### 5.4 PatentFishiGrowthEcoAdapter 预留

`model_tools/growth_eco/` 下创建：

```text
simulation.py
schemas.py
README.md
```

第一期只需要：

```text
1. 把原 Patent_fishi.py 的 ODE 模型思路改造成纯函数，不画图，不 plt.show。
2. 函数返回 JSON-compatible dict。
3. 如果时间不够，只保留 adapter 类和 TODO，不接入主流程。
4. 主流程默认仍使用 mock，避免模型调参阻塞工程闭环。
```

后续真实接入时，它应输出：

```text
鱼群数量 N
单体体重 W
总生物量 B
投饵量 F
水温 T
DO
TN
TP
叶绿素 C
累积氮磷排放
```

##### 5.5 BiomassEstimationTool

```python
class BiomassEstimationTool:
    def estimate_current(self, avg_weight_g: float, survival_count: int) -> dict: ...
    def estimate_series(self, growth_series: list[dict], survival_count: int) -> list[dict]: ...
```

##### 5.6 FeedingPlanTool

职责：

```text
根据预测体重、生物量、阶段和风险生成分周投喂/采样/巡检计划。
```

输出：

```json
{
  "summary": "未来 30 天以稳定增重和低风险投喂为主。",
  "weekly_plan": [
    {
      "week_index": 1,
      "date_range": ["2026-06-01", "2026-06-07"],
      "growth_stage": "growout",
      "feeding_strategy": "维持当前投喂强度，避免单周增幅超过 15%",
      "estimated_daily_feed_kg": 180.0,
      "sampling_plan": "本周无需体测；下次体测安排在 2026-06-14",
      "inspection_plan": "每日巡检，夜间关注溶氧"
    }
  ]
}
```

阶段规则：

```text
juvenile: W < 100g
growout: 100g <= W < 400g
pre_harvest: W >= 400g
```

Demo 投喂率：

```text
juvenile: 3.0% - 5.0% biomass/day
growout: 1.8% - 3.0% biomass/day
pre_harvest: 1.0% - 2.0% biomass/day
```

响应必须把这些数值写入 `assumptions`，说明它们是第一期 demo 假设。

##### 5.7 RiskRuleTool

第一期规则：

```text
数据缺失风险：没有体测记录、水质记录为空、最近体测超过 21 天。
低氧风险：DO 均值 < 5 mg/L，或最小 DO < 4 mg/L。
温度风险：水温低于 18°C 或高于 30°C，或偏离 25°C 过大。
生长目标风险：target_date 前无法达到 target_weight_g。
投喂调整风险：分周投喂建议变化超过约束阈值。
```

输出：

```json
{
  "risk_level": "medium",
  "risks": [
    {
      "type": "data_quality",
      "level": "medium",
      "message": "最近体测距离规划开始时间超过 21 天，建议补充抽样。"
    }
  ],
  "rules_triggered": ["measurement_stale"]
}
```

---

#### 功能 6：结构化生产计划输出

`POST /api/production/plan` 的响应必须包含以下字段：

```json
{
  "request_id": "uuid",
  "batch_id": "BATCH_A",
  "planning_window": {},
  "current_state": {},
  "data_quality": {},
  "environment_summary": {},
  "growth_prediction": {},
  "production_plan": {},
  "risk_assessment": {},
  "action_items": [],
  "assumptions": [],
  "missing_data": [],
  "explanation": "",
  "debug_trace": []
}
```

禁止只返回自然语言。  
前端要依赖这些字段展示卡片、表格和曲线。

---

#### 功能 7：本地前端生产规划工作台

前端路径：

```text
apps/web
```

第一期前端不要只做聊天框，必须做一个最小工作台：

```text
左侧：批次选择 + 时间窗输入 + 目标规格 + 目标日期
中间：生产规划结果
右侧：解释与 debug_trace
```

组件：

```text
BatchSelector
PlanningWindowForm
ProductionPlanView
GrowthCurve
WeeklyPlanTable
RiskCards
ActionItems
DebugTracePanel
ChatPanel
```

第一期可以简单，但必须可用。

---

#### 功能 8：服务器部署链路

已知部署约束：

```text
前端：本地运行
本地编译/启动：conda activate rag_task
后端：ssh lijiyao 后 ssh gpu6000
后端运行方式：容器 + tmux 后台
```

建议端口：

```text
后端远端端口：8797
本地映射端口：8797
前端端口：3007
```

必须生成：

```text
deploy/backend.Containerfile
deploy/backend.apptainer.def
deploy/server_start_tmux.sh
deploy/server_stop_tmux.sh
deploy/server_logs.sh
deploy/local_tunnel.sh
deploy/local_start_frontend.sh
```

---

## 2. 第一期不要做的功能

请 Codex 不要在第一期做这些事：

```text
1. 不接真实数据库。
2. 不做完整销售规划。
3. 不把 MFPCA_paper.R 放入主生产规划链路。
4. 不强依赖 LLM 才能生成计划。
5. 不做复杂权限系统。
6. 不做大而全的多智能体系统。
7. 不把所有业务逻辑写进 prompt。
8. 不在服务器上随意占用多个新端口。
9. 不把 API Key、SSH 私钥、服务器密码写进仓库。
10. 不让 matplotlib plt.show 阻塞后端服务。
```

MFPCA 的第一期处理方式：

```text
1. model_tools/mfpca/ 下创建 README.md 和 placeholder。
2. 预留 WaterQualityMfpcaTool 接口。
3. 不作为 /api/production/plan 的必需步骤。
4. 后续 V2/V3 再做 R 脚本精简、容器化和异步任务。
```

---

## 3. 推荐仓库结构

请 Codex 创建或整理为：

```text
aquaculture-agent/
├── AGENTS.md
├── README.md
├── .env.example
├── requirements.txt
├── pyproject.toml
├── backend/
│   ├── app.py
│   ├── config.py
│   ├── graph/
│   │   ├── __init__.py
│   │   ├── state.py
│   │   ├── builder.py
│   │   ├── routers.py
│   │   └── nodes/
│   │       ├── __init__.py
│   │       ├── parse_intent.py
│   │       ├── normalize_window.py
│   │       ├── load_batch_context.py
│   │       ├── check_data_quality.py
│   │       ├── summarize_environment.py
│   │       ├── run_growth_projection.py
│   │       ├── estimate_biomass.py
│   │       ├── generate_feeding_plan.py
│   │       ├── assess_risk.py
│   │       ├── generate_action_items.py
│   │       └── write_response.py
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── database_tool.py
│   │   ├── water_quality_tool.py
│   │   ├── growth_model_tool.py
│   │   ├── biomass_tool.py
│   │   ├── feeding_plan_tool.py
│   │   ├── risk_rule_tool.py
│   │   ├── report_writer_tool.py
│   │   └── tool_registry.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── data_service.py
│   │   ├── model_service.py
│   │   ├── production_planning_service.py
│   │   └── llm_service.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── common.py
│   │   ├── batch.py
│   │   ├── production.py
│   │   ├── risk.py
│   │   └── agent.py
│   ├── data/
│   │   ├── demo_batches.csv
│   │   ├── demo_water_quality.csv
│   │   ├── demo_body_measurements.csv
│   │   ├── demo_feeding_records.csv
│   │   └── demo_mortality_records.csv
│   └── tests/
│       ├── test_health.py
│       ├── test_window_normalization.py
│       ├── test_batch_profile.py
│       ├── test_growth_projection.py
│       └── test_production_plan_api.py
├── apps/
│   └── web/
│       ├── app/
│       │   ├── page.tsx
│       │   ├── layout.tsx
│       │   └── globals.css
│       ├── components/
│       │   ├── BatchSelector.tsx
│       │   ├── PlanningWindowForm.tsx
│       │   ├── ProductionPlanView.tsx
│       │   ├── GrowthCurve.tsx
│       │   ├── WeeklyPlanTable.tsx
│       │   ├── RiskCards.tsx
│       │   ├── ActionItems.tsx
│       │   ├── DebugTracePanel.tsx
│       │   └── ChatPanel.tsx
│       ├── lib/
│       │   ├── api.ts
│       │   └── types.ts
│       ├── package.json
│       ├── next.config.js
│       └── tsconfig.json
├── model_tools/
│   ├── growth_eco/
│   │   ├── __init__.py
│   │   ├── simulation.py
│   │   ├── schemas.py
│   │   └── README.md
│   └── mfpca/
│       ├── README.md
│       └── placeholder.md
├── deploy/
│   ├── backend.Containerfile
│   ├── backend.apptainer.def
│   ├── env.example
│   ├── server_start_tmux.sh
│   ├── server_stop_tmux.sh
│   ├── server_logs.sh
│   ├── local_tunnel.sh
│   └── local_start_frontend.sh
├── scripts/
│   ├── dev_backend.sh
│   ├── dev_frontend.sh
│   ├── seed_demo_data.py
│   └── smoke_test.sh
└── docs/
    ├── ARCHITECTURE.md
    ├── API.md
    ├── DEPLOYMENT.md
    └── CODEX_TASKS.md
```

---

## 4. 后端 API 明细

### 4.1 健康检查

```text
GET /health
```

返回：

```json
{
  "status": "ok",
  "service": "aquaculture-agent-api",
  "version": "0.1.0"
}
```

### 4.2 批次列表

```text
GET /api/batches
```

返回：

```json
[
  {
    "batch_id": "BATCH_A",
    "cage_id": "CAGE_03",
    "species": "large_yellow_croaker",
    "current_avg_weight_g": 120.5,
    "estimated_biomass_kg": 7591.5,
    "target_weight_g": 600,
    "target_date": "2026-10-30"
  }
]
```

### 4.3 批次画像

```text
GET /api/batches/{batch_id}/profile
```

### 4.4 生产规划

```text
POST /api/production/plan
```

请求示例：

```json
{
  "batch_id": "BATCH_A",
  "horizon_days": 30,
  "planning_start": null,
  "planning_end": null,
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "user_goal": "希望控制风险，并尽量按目标规格上市",
  "constraints": {
    "max_feed_change_ratio_per_week": 0.15,
    "sampling_interval_days": 14,
    "risk_tolerance": "medium"
  },
  "use_llm": false
}
```

### 4.5 智能体聊天入口

```text
POST /api/agent/chat
```

第一期做薄封装即可：从自然语言中尽量解析 `batch_id` 和 `horizon_days`，然后调用 production plan。  
如果解析失败，返回结构化错误，不要崩溃。

---

## 5. AgentState 设计

在 `backend/graph/state.py` 中实现：

```python
from typing import Any, Literal, TypedDict

PlanningMode = Literal[
    "future_plan",
    "current_to_future",
    "historical_review",
    "target_backcast",
]

class AgentState(TypedDict, total=False):
    request_id: str
    user_query: str
    task_type: str

    batch_id: str
    cage_id: str
    species: str

    planning_start: str | None
    planning_end: str | None
    horizon_days: int | None
    target_weight_g: float | None
    target_date: str | None
    planning_mode: PlanningMode

    constraints: dict[str, Any]
    use_llm: bool

    batch_profile: dict[str, Any]
    water_quality_history: list[dict[str, Any]]
    body_measurements: list[dict[str, Any]]
    feeding_records: list[dict[str, Any]]
    mortality_records: list[dict[str, Any]]

    data_quality: dict[str, Any]
    environment_summary: dict[str, Any]
    growth_prediction: dict[str, Any]
    biomass_estimation: dict[str, Any]
    production_plan: dict[str, Any]
    risk_assessment: dict[str, Any]
    action_items: list[dict[str, Any]]

    assumptions: list[str]
    missing_data: list[str]
    debug_trace: list[str]
    final_response: dict[str, Any]
    error: str | None
```

---

## 6. Demo 数据

请创建以下 CSV。

### 6.1 demo_batches.csv

```csv
batch_id,cage_id,species,stocking_date,initial_count,initial_avg_weight_g,initial_avg_length_cm,current_estimated_count,target_weight_g,target_date
BATCH_A,CAGE_03,large_yellow_croaker,2026-04-01,65000,10,8.5,63000,600,2026-10-30
BATCH_B,CAGE_05,large_yellow_croaker,2026-05-15,80000,8,7.9,79200,550,2026-11-15
```

### 6.2 demo_body_measurements.csv

```csv
batch_id,measurement_date,avg_weight_g,avg_length_cm,sample_count
BATCH_A,2026-04-01,10,8.5,100
BATCH_A,2026-05-01,42,12.8,120
BATCH_A,2026-06-01,120.5,18.2,120
BATCH_B,2026-05-15,8,7.9,100
BATCH_B,2026-06-01,21,10.5,120
```

### 6.3 demo_water_quality.csv

请生成至少 60 条 CAGE_03 和 CAGE_05 的水质记录，字段：

```csv
cage_id,timestamp,temperature_c,do_mg_l,salinity_ppt,ph,flow_m_s,turbidity_ntu
```

要求数据包含：

```text
1. 正常水质。
2. 少量夜间 DO 偏低记录。
3. 温度在 22-28°C 附近波动。
```

### 6.4 demo_feeding_records.csv

```csv
batch_id,date,feed_type,feed_amount_kg,feeding_times,feeding_note
BATCH_A,2026-05-30,growout_feed,520,3,normal
BATCH_A,2026-05-31,growout_feed,535,3,normal
BATCH_B,2026-05-31,starter_feed,260,4,normal
```

### 6.5 demo_mortality_records.csv

```csv
batch_id,date,mortality_count,reason
BATCH_A,2026-05-30,20,normal_loss
BATCH_A,2026-05-31,18,normal_loss
BATCH_B,2026-05-31,15,normal_loss
```

---

## 7. 环境变量

`.env.example`：

```bash
APP_NAME=aquaculture-agent
APP_ENV=development
BACKEND_HOST=127.0.0.1
BACKEND_PORT=8797
FRONTEND_PORT=3007

DATA_BACKEND=csv
DEMO_DATA_DIR=backend/data

USE_LLM=false
OPENAI_API_KEY=
OPENAI_BASE_URL=http://127.0.0.1:8001/v1
OPENAI_MODEL=Qwen3-VL-8B-Instruct

GROWTH_MODEL_BACKEND=mock
AGENT_DEBUG=true
LOG_LEVEL=INFO
```

---

## 8. Codex 执行任务拆解

请 Codex 严格按顺序做。每个任务完成后运行对应测试，再进行下一个任务。

### Task 0：初始化项目骨架

要求：

```text
1. 创建全部目录结构。
2. 创建 AGENTS.md、README.md、.env.example。
3. 创建 docs/ARCHITECTURE.md、docs/API.md、docs/DEPLOYMENT.md、docs/CODEX_TASKS.md。
4. 创建 requirements.txt、pyproject.toml。
5. 创建 backend/tests 空测试文件。
```

验收：

```bash
find . -maxdepth 3 -type f | sort
```

---

### Task 1：实现 demo 数据和 CSV 数据服务

要求：

```text
1. 创建 backend/data 下 5 个 demo CSV。
2. 实现 backend/services/data_service.py。
3. 实现 DatabaseQueryTool。
4. 支持按 batch_id 和时间范围查询。
```

验收：

```bash
pytest backend/tests/test_batch_profile.py -q
```

---

### Task 2：实现 FastAPI 基础接口

要求：

```text
1. backend/app.py 实现 FastAPI。
2. GET /health。
3. GET /api/batches。
4. GET /api/batches/{batch_id}/profile。
5. 异常响应为 JSON。
```

验收：

```bash
uvicorn backend.app:app --host 127.0.0.1 --port 8797
curl http://127.0.0.1:8797/health
curl http://127.0.0.1:8797/api/batches
curl http://127.0.0.1:8797/api/batches/BATCH_A/profile
```

---

### Task 3：实现时间窗规范化

要求：

```text
1. 实现 normalize_planning_window。
2. 支持 horizon_days。
3. 支持 planning_start/planning_end。
4. 支持 target_weight_g/target_date。
5. 支持 future_plan、current_to_future、target_backcast。
6. historical_review 只需保留枚举和基础测试。
```

验收：

```bash
pytest backend/tests/test_window_normalization.py -q
```

---

### Task 4：实现生产规划工具层

要求：

```text
1. WaterQualityTool。
2. BiomassEstimationTool。
3. GrowthModelTool + MockGrowthModelAdapter。
4. FeedingPlanTool。
5. RiskRuleTool。
6. ReportWriterTool。
7. ToolRegistry。
```

验收：

```bash
pytest backend/tests/test_growth_projection.py -q
```

---

### Task 5：实现 LangGraph 主流程

要求：

```text
1. backend/graph/state.py。
2. backend/graph/builder.py。
3. backend/graph/routers.py。
4. backend/graph/nodes 下全部节点。
5. POST /api/production/plan 调用 LangGraph。
6. debug_trace 包含每个节点名。
7. use_llm=false 可完整执行。
```

验收：

```bash
curl -X POST http://127.0.0.1:8797/api/production/plan \
  -H 'Content-Type: application/json' \
  -d '{
    "batch_id":"BATCH_A",
    "horizon_days":30,
    "target_weight_g":600,
    "target_date":"2026-10-30",
    "use_llm":false
  }' | python -m json.tool
```

响应必须看到：

```text
planning_window
current_state
environment_summary
growth_prediction.series
production_plan.weekly_plan
risk_assessment
action_items
assumptions
debug_trace
```

---

### Task 6：实现 agent chat 薄入口

要求：

```text
1. POST /api/agent/chat。
2. 第一版只支持简单解析：
   - “A 批” → BATCH_A
   - “未来 30 天” → horizon_days=30
   - “600g” → target_weight_g=600
3. 内部复用 production_plan。
4. 解析失败时返回可解释错误，不要崩溃。
```

---

### Task 7：实现本地前端 V1

要求：

```text
1. apps/web 创建 Next.js + TypeScript。
2. 页面包含批次选择、时间窗表单、目标规格和目标日期。
3. 调用 /api/batches 和 /api/production/plan。
4. 展示：
   - 当前状态卡片
   - 生长预测曲线
   - 分周计划表
   - 风险卡片
   - 行动事项
   - debug_trace
5. UI 简洁即可，但不能只有 JSON textarea。
```

本地验收：

```bash
conda activate rag_task
cd apps/web
npm install
NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8797 npm run dev -- --port 3007
```

---

### Task 8：实现部署脚本

要求：

```text
1. deploy/backend.Containerfile。
2. deploy/backend.apptainer.def。
3. deploy/server_start_tmux.sh。
4. deploy/server_stop_tmux.sh。
5. deploy/server_logs.sh。
6. deploy/local_tunnel.sh。
7. deploy/local_start_frontend.sh。
8. scripts/smoke_test.sh。
```

`deploy/local_tunnel.sh` 默认：

```bash
JUMP_HOST=lijiyao
REMOTE_HOST=gpu6000
LOCAL_PORT=8797
REMOTE_PORT=8797
```

使用：

```bash
ssh -N -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} -J ${JUMP_HOST} ${REMOTE_HOST}
```

`deploy/local_start_frontend.sh` 必须使用：

```bash
conda activate rag_task
cd apps/web
npm install
npm run dev -- --port 3007
```

---

### Task 9：写文档和最终验收

要求：

```text
1. README.md 写清楚项目定位和启动方式。
2. docs/API.md 写清楚 API schema。
3. docs/DEPLOYMENT.md 写清楚本地前端、SSH 隧道、远端后端启动方式。
4. docs/ARCHITECTURE.md 写清楚 LangGraph 和 Tools 结构。
5. docs/CODEX_TASKS.md 记录任务完成情况。
```

最终验收：

```bash
pytest -q
bash scripts/smoke_test.sh
```

---

## 9. AGENTS.md 内容建议

请 Codex 在仓库根目录创建 `AGENTS.md`，内容如下：

```markdown
# AGENTS.md

## Project

This repository implements an aquaculture production planning agent for offshore/deep-sea cage farming.

The core business object is Batch / Digital Fish Asset. Do not design the system around a single sensor or one-off chat response.

## First-phase scope

Implement a V1 production planning agent for arbitrary early-stage planning windows.

Must support:
- FastAPI backend
- LangGraph workflow
- Pydantic schemas
- CSV demo data
- Next.js local frontend
- SSH tunnel to remote backend
- container + tmux deployment on gpu6000
- deterministic planning with USE_LLM=false

Do not implement full sales planning, real database integration, full R/MFPCA execution, auth, or complex multi-agent orchestration in V1.

## Environment

Local frontend development:
- activate conda environment `rag_task`
- frontend runs under `apps/web`
- default frontend port: 3007

Remote backend:
- ssh lijiyao
- ssh gpu6000
- run backend in container + tmux
- default backend port: 8797
- bind remote backend to 127.0.0.1 where possible

## Code conventions

- Keep business logic in `backend/tools` and `backend/services`.
- Keep LangGraph node functions thin.
- Every graph node must append its node name to `debug_trace`.
- All production plan API responses must be structured JSON.
- The system must work when `USE_LLM=false`.
- Do not store secrets in the repository.
- Do not use matplotlib `plt.show()` in backend request paths.
- Add tests for every new tool or graph behavior.

## Required validation

Run before marking work complete:
- pytest -q
- bash scripts/smoke_test.sh

If frontend files change:
- cd apps/web
- npm run lint if configured
- npm run build if feasible
```

---

## 10. 首条给 Codex 的完整提示词

把下面整段直接交给 Codex：

```text
请根据本计划初始化并实现 aquaculture-agent 项目的第一期功能。

项目目标：
搭建“深远海养殖前期任意时段生产规划智能体”的最小可运行版本。核心对象是养殖批次 Batch，不是单个传感器或单个模型。系统应支持用户输入 batch_id、未来天数或任意日期时间窗，读取 demo 批次/水质/体测/投喂/死亡数据，调用生长预测和风险规则，输出结构化生产计划 JSON，并在本地 Next.js 前端展示。

硬性要求：
1. 后端：FastAPI + LangGraph + Pydantic。
2. 前端：apps/web 下的 Next.js + TypeScript。
3. 数据：第一期使用 CSV demo 数据。
4. 接口：GET /health、GET /api/batches、GET /api/batches/{batch_id}/profile、POST /api/production/plan、POST /api/agent/chat。
5. POST /api/production/plan 支持 horizon_days、planning_start/planning_end、target_weight_g/target_date。
6. LangGraph 节点包括 parse_intent、normalize_planning_window、load_batch_context、check_data_quality、summarize_environment、run_growth_projection、estimate_biomass、generate_feeding_plan、assess_risk、generate_action_items、write_response。
7. use_llm=false 时也必须能生成完整生产计划。
8. 响应必须是结构化 JSON，包含 planning_window、current_state、environment_summary、growth_prediction、production_plan、risk_assessment、action_items、assumptions、debug_trace。
9. 保留 GrowthModelAdapter / ToolRegistry / Graph Router 扩展点，后续方便接入 Patent_fishi.py、MFPCA_paper.R、生产调整和销售规划。
10. 第一期开启 MockGrowthModelAdapter；PatentFishiGrowthEcoAdapter 只做可替换接口或轻量封装，不要让它阻塞主流程。
11. MFPCA 第一阶段只做 model_tools/mfpca 占位和 WaterQualityMfpcaTool 预留，不要接入主流程。
12. 本地前端启动必须说明使用 conda activate rag_task。
13. 后端部署在 ssh lijiyao -> ssh gpu6000，容器 + tmux 后台运行，默认端口 8797。
14. 生成部署脚本：server_start_tmux.sh、server_stop_tmux.sh、server_logs.sh、local_tunnel.sh、local_start_frontend.sh。
15. 创建 AGENTS.md，写入项目规则、环境约束和测试要求。
16. 添加 pytest 和 scripts/smoke_test.sh。
17. 不要写入任何 API Key、SSH 私钥或服务器密码。

请按任务顺序实现：
Task 0 初始化项目骨架
Task 1 demo 数据和 CSV 数据服务
Task 2 FastAPI 基础接口
Task 3 时间窗规范化
Task 4 工具层
Task 5 LangGraph 主流程
Task 6 agent chat 薄入口
Task 7 本地前端
Task 8 部署脚本
Task 9 文档和验收

每完成一个任务请运行对应测试，并在 docs/CODEX_TASKS.md 记录已完成项、测试命令和结果。
```

---

## 11. Definition of Done

第一期完成标准：

```text
1. /health 可访问。
2. /api/batches 可返回 demo 批次。
3. /api/batches/BATCH_A/profile 可返回批次画像和估算生物量。
4. /api/production/plan 可对 BATCH_A 生成未来 30 天生产计划。
5. /api/production/plan 可接受 planning_start/planning_end。
6. /api/production/plan 可接受 target_weight_g/target_date。
7. 响应包含 debug_trace，可看到 LangGraph 节点路径。
8. use_llm=false 能完整运行。
9. 本地前端能展示生产计划，不只是 JSON。
10. 本地通过 SSH tunnel 能访问远端 gpu6000 后端。
11. 远端后端可以用容器 + tmux 后台运行。
12. pytest -q 通过。
13. bash scripts/smoke_test.sh 通过。
14. README、API、DEPLOYMENT、ARCHITECTURE 文档完整。
15. 后续可以替换 GrowthModelTool 为 PatentFishiGrowthEcoAdapter。
16. 后续可以新增 WaterQualityMfpcaTool，但不会影响当前主流程。
```

---

## 12. 后续二期预告

第一期完成后再做：

```text
V2：把 Patent_fishi.py 正式封装为 GrowthEcoSimulationTool，并替换 mock 模型。
V3：加入生产过程调整 flow，支持实际生长 vs 预测生长偏差分析。
V4：把 MFPCA_paper.R 精简成独立 WaterQualityMfpcaTool，作为水质空间预警工具。
V5：加入销售规划 flow，把生产规划结果连接到上市窗口、生物资产评估和销售建议。
V6：接入真实数据库、时序数据、水质设备数据和长期记忆。
```

