# Codex 项目开始计划：深远海养殖前期任意时段生产规划智能体

> 目标：先搭建一个具备良好扩展性的“深远海养殖前期生产规划智能体”工程骨架。它应支持用户对任意养殖时间窗提出生产规划问题，例如“从 2026-06-01 到 2026-07-15 怎么养”“未来 30 天如何安排投喂/采样/巡检”“按目标 600g 上市规格倒推前期生产计划”。
>
> 技术栈可参考 `UTSJiyaoLi/Wind-Agent` 的组织方式和部署思路，但不要直接照搬台风/风场业务模式。本项目业务核心是 **养殖批次 Batch / 生物资产 Digital Fish Asset**。

---

## 0. 一句话定位

本项目不是普通问答机器人，而是：

> 以养殖批次为核心，面向任意生产时间窗，调用批次数据、水质数据、体测数据、生长模型、投喂规则和风险规则，输出结构化生产计划的 LangGraph 智能体后端，并通过本地前端 + SSH 隧道访问远端服务。

第一阶段只做 **前期生产规划**，暂不把销售规划作为主流程，但工程结构要预留销售、MFPCA、水质空间分析、R 工具、溯源报告等扩展位。

---

## 1. 参考 Wind-Agent 时只借鉴什么

参考仓库：`https://github.com/UTSJiyaoLi/Wind-Agent`

从 Wind-Agent 借鉴：

1. **本地前端 + 远端后端 + SSH 隧道** 的运行方式。
2. `apps/web` 作为前端目录。
3. `graph / tools / services / schemas / rag / configs / scripts` 的工程分层。
4. FastAPI 作为后端 API 入口。
5. LangGraph 作为流程编排层。
6. 远端服务用 `tmux` 长期运行。
7. 远端模型/后端服务不要重复开实例，应复用已有端口或明确新增端口。

不要照搬：

1. 台风/风场预测业务逻辑。
2. 过早引入复杂 RAG。
3. 过早把所有功能塞进一个 Agent。
4. 前端只做 Chat UI 而缺少批次生产计划结构化展示。

---

## 2. 已知部署约束

### 2.1 前端

前端运行在本地机器。

本地如果需要编译、启动或运行脚本，请使用：

```bash
conda activate rag_task
```

前端建议采用：

```text
Next.js + TypeScript + TailwindCSS
```

本地前端通过 SSH 隧道访问远端后端。

### 2.2 后端

后端运行在服务器：

```bash
ssh lijiyao
ssh gpu6000
```

或者如果本地 SSH 配置支持 ProxyJump，可以使用：

```bash
ssh -J lijiyao gpu6000
```

后端要求：

```text
FastAPI + LangGraph + Pydantic + pandas/numpy/scipy
容器运行
使用 tmux 后台保持服务
```

### 2.3 建议端口

为避免和 Wind-Agent 现有端口冲突，初始建议使用：

```text
远端后端端口：8797
本地映射端口：8797
前端端口：3007
```

Codex 需要把端口都做成 `.env` 配置，不要写死。

---

## 3. 架构结论

推荐：

```text
LangGraph = 主业务状态图
LangChain = Tool/LLM 调用接口，可选
FastAPI = 服务入口
Pydantic = 请求/响应/状态结构
CSV/SQLite = V0 数据层
PostgreSQL/TimescaleDB = 后续生产数据层
Next.js = 本地前端
SSH Tunnel = 本地访问远端服务
Container + tmux = 远端长期运行
```

第一版必须保证：

1. **没有 LLM 也能跑通 deterministic 生产规划**。
2. 有 LLM 时可以做意图解析和解释生成。
3. 所有关键计算逻辑都在工具层和服务层，而不是 Prompt 里。
4. 所有输出都返回结构化 JSON，前端再渲染成卡片、表格和曲线。

---

## 4. 业务核心：任意时段生产规划

“任意时段”不是简单 `horizon_days`，而是要支持不同时间窗模式。

### 4.1 输入时间窗规范

API 请求应支持以下几种方式：

```json
{
  "batch_id": "BATCH_A",
  "planning_start": "2026-06-01",
  "planning_end": "2026-07-15"
}
```

或：

```json
{
  "batch_id": "BATCH_A",
  "horizon_days": 30
}
```

或：

```json
{
  "batch_id": "BATCH_A",
  "target_weight_g": 600,
  "target_date": "2026-10-30"
}
```

### 4.2 时间窗类型

Codex 需要实现 `normalize_planning_window`，自动判断：

```text
1. future_plan
   planning_start >= 当前日期
   用当前批次状态 + 预测模型生成未来计划

2. current_to_future
   planning_start <= 当前日期 <= planning_end
   历史段读取真实数据，未来段调用模型预测，两段拼接

3. historical_review
   planning_end < 当前日期
   用历史数据做复盘，不生成未来投喂执行任务，但输出偏差分析

4. target_backcast
   用户给目标规格/目标日期
   倒推生产节奏、采样频率和风险控制策略
```

V0 可以重点实现 `future_plan` 和 `current_to_future`，但状态设计必须预留四种模式。

---

## 5. 最小可用场景

V0 项目启动后必须能完成三个前期生产规划场景。

### 场景 A：未来 30 天生产计划

用户：

```text
帮我为 A 批鱼制定未来 30 天生产计划。
```

输出：

```text
当前状态
未来体重/体长预测
未来生物量预测
投喂计划
体测采样计划
巡检计划
水质风险
行动事项
假设条件
```

### 场景 B：指定时间段生产计划

用户：

```text
帮我规划 A 批鱼从 2026-06-01 到 2026-07-15 的生产安排。
```

输出：

```text
时间窗类型
该时段阶段判断
分周计划
关键监测指标
风险规则
需要人工确认的数据
```

### 场景 C：目标规格倒推

用户：

```text
A 批鱼希望 10 月底达到 600g，前期应该怎么安排？
```

输出：

```text
目标可达性
预计达规格时间
是否需要调整投喂强度
采样频率
水质风险控制
关键里程碑
```

---

## 6. 推荐仓库结构

Codex 请创建或整理为如下结构：

```text
aquaculture-agent/
├── apps/
│   └── web/
│       ├── app/
│       │   ├── page.tsx
│       │   ├── layout.tsx
│       │   └── globals.css
│       ├── components/
│       │   ├── ChatPanel.tsx
│       │   ├── BatchSelector.tsx
│       │   ├── ProductionPlanView.tsx
│       │   ├── GrowthCurve.tsx
│       │   ├── RiskCards.tsx
│       │   └── ActionItems.tsx
│       ├── lib/
│       │   ├── api.ts
│       │   └── types.ts
│       ├── package.json
│       ├── next.config.js
│       └── tsconfig.json
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
│   │   └── report_writer_tool.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── data_service.py
│   │   ├── production_planning_service.py
│   │   ├── model_service.py
│   │   ├── llm_service.py
│   │   └── telemetry_service.py
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
├── docs/
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── CODEX_TASKS.md
├── requirements.txt
├── pyproject.toml
├── README.md
└── .env.example
```

---

## 7. 后端 API 设计

### 7.1 健康检查

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

### 7.2 批次列表

```text
GET /api/batches
```

返回批次摘要。

### 7.3 批次画像

```text
GET /api/batches/{batch_id}/profile
```

返回：

```json
{
  "batch_id": "BATCH_A",
  "cage_id": "CAGE_03",
  "species": "large_yellow_croaker",
  "stocking_date": "2026-04-01",
  "initial_count": 65000,
  "estimated_survival_count": 63000,
  "current_avg_weight_g": 120.5,
  "current_avg_length_cm": 18.2,
  "estimated_biomass_kg": 7591.5,
  "target_weight_g": 600,
  "target_date": "2026-10-30"
}
```

### 7.4 生产规划主接口

```text
POST /api/production/plan
```

请求：

```json
{
  "batch_id": "BATCH_A",
  "planning_start": "2026-06-01",
  "planning_end": "2026-07-15",
  "horizon_days": null,
  "target_weight_g": 600,
  "target_date": "2026-10-30",
  "user_goal": "希望控制风险，并尽量按目标规格上市",
  "constraints": {
    "max_feed_change_ratio_per_week": 0.15,
    "sampling_interval_days": 14,
    "risk_tolerance": "medium"
  },
  "use_llm": true
}
```

响应必须是结构化 JSON：

```json
{
  "request_id": "uuid",
  "batch_id": "BATCH_A",
  "planning_window": {
    "mode": "future_plan",
    "start_date": "2026-06-01",
    "end_date": "2026-07-15",
    "horizon_days": 45
  },
  "current_state": {
    "current_avg_weight_g": 120.5,
    "current_avg_length_cm": 18.2,
    "estimated_survival_count": 63000,
    "estimated_biomass_kg": 7591.5
  },
  "data_quality": {
    "status": "usable",
    "missing_data": [],
    "warnings": []
  },
  "environment_summary": {
    "avg_temperature_c": 24.3,
    "avg_do_mg_l": 7.2,
    "risk_notes": []
  },
  "growth_prediction": {
    "series": [
      {"date": "2026-06-01", "avg_weight_g": 120.5, "avg_length_cm": 18.2, "biomass_kg": 7591.5}
    ],
    "estimated_target_date": "2026-10-21",
    "target_achievable": true
  },
  "production_plan": {
    "summary": "未来 45 天以稳定增重和低风险投喂为主。",
    "weekly_plan": [
      {
        "week_index": 1,
        "date_range": ["2026-06-01", "2026-06-07"],
        "feeding_strategy": "维持当前投喂强度，避免单周增幅超过 15%",
        "sampling_plan": "无需体测；下次体测安排在 2026-06-14",
        "inspection_plan": "每日巡检，夜间关注溶氧"
      }
    ]
  },
  "risk_assessment": {
    "risk_level": "low",
    "risks": [],
    "rules_triggered": []
  },
  "action_items": [
    {
      "date": "2026-06-14",
      "priority": "medium",
      "task": "进行一次体重体长抽样"
    }
  ],
  "assumptions": [
    "V0 使用 demo 水质数据和 mock 生长模型",
    "市场销售和起捕规划暂未纳入本接口"
  ],
  "explanation": "本计划基于批次当前体重、历史水质和目标规格生成。",
  "debug_trace": ["parse_intent", "normalize_window", "load_batch_context"]
}
```

### 7.5 智能体聊天接口

```text
POST /api/agent/chat
```

用途：自然语言入口。V0 内部仍路由到 `/api/production/plan`。

请求：

```json
{
  "message": "帮我规划 A 批鱼未来 30 天怎么养",
  "batch_id": "BATCH_A",
  "use_llm": true
}
```

---

## 8. LangGraph 状态设计

Codex 请在 `backend/graph/state.py` 中实现一个 TypedDict 或 Pydantic 兼容状态。

建议状态：

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

    batch_profile: dict[str, Any]
    water_quality_history: list[dict[str, Any]]
    recent_water_quality: dict[str, Any]
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

## 9. LangGraph 工作流

### 9.1 主图

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
route_by_planning_mode
      ├── future_plan_flow
      ├── current_to_future_flow
      ├── historical_review_flow      # V1/V2
      └── target_backcast_flow        # V1/V2
```

V0 可先让四个分支都进入同一条生产规划线，但必须保留 router。

### 9.2 future_plan_flow

```text
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

### 9.3 current_to_future_flow

```text
split_historical_and_future_window
  ↓
summarize_historical_environment
  ↓
compare_recent_growth_if_available
  ↓
run_growth_projection_for_future_part
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

---

## 10. 工具层设计

工具层必须是可测试的纯业务能力，不要依赖 FastAPI 请求对象。

### 10.1 DatabaseQueryTool

职责：

```text
读取 demo CSV / SQLite 中的批次、体测、水质、投喂、死亡记录。
```

接口示例：

```python
class DatabaseQueryTool:
    def get_batch(self, batch_id: str) -> dict: ...
    def list_batches(self) -> list[dict]: ...
    def get_body_measurements(self, batch_id: str, start: str | None, end: str | None) -> list[dict]: ...
    def get_feeding_records(self, batch_id: str, start: str | None, end: str | None) -> list[dict]: ...
    def get_mortality_records(self, batch_id: str, start: str | None, end: str | None) -> list[dict]: ...
```

### 10.2 WaterQualityTool

职责：

```text
按 batch_id/cage_id 和时间窗读取水质，并输出统计摘要。
```

接口示例：

```python
class WaterQualityTool:
    def get_history(self, cage_id: str, start: str | None, end: str | None) -> list[dict]: ...
    def summarize(self, records: list[dict]) -> dict: ...
```

### 10.3 GrowthModelTool

V0 先 mock，但接口必须能替换为 `Patent_fishi.py` 封装后的真实模型。

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

V0 mock 规则建议：

```text
基础日增长率由当前体重阶段决定。
水温偏离适温越大，增长率越低。
溶氧低于阈值时，增长率下调。
输出每日或每周 weight/length/biomass series。
```

### 10.4 BiomassEstimationTool

```python
class BiomassEstimationTool:
    def estimate_current(self, avg_weight_g: float, survival_count: int) -> dict: ...
    def estimate_series(self, growth_series: list[dict], survival_count: int) -> list[dict]: ...
```

### 10.5 FeedingPlanTool

```python
class FeedingPlanTool:
    def generate_weekly_plan(
        self,
        growth_prediction: dict,
        batch_profile: dict,
        risk_assessment: dict | None,
        constraints: dict,
    ) -> dict: ...
```

第一版使用规则：

```text
鱼体越小，投喂率可相对高；鱼体越接近上市规格，投喂率逐步降低。
单周投喂强度调整不超过 max_feed_change_ratio_per_week。
若 DO 风险中高，建议降低投喂或避免夜间高强度投喂。
```

### 10.6 RiskRuleTool

```python
class RiskRuleTool:
    def assess(self, environment_summary: dict, growth_prediction: dict, data_quality: dict) -> dict: ...
```

V0 风险规则：

```text
数据缺失风险：关键表缺失或最近体测超过 21 天。
低氧风险：DO 均值 < 5 mg/L 或夜间低于 4 mg/L。
高温/低温风险：水温偏离适温区间。
生长滞后风险：目标日期前难以达到目标规格。
投喂风险：建议投喂强度变化过大。
```

---

## 11. 数据模型与 Demo 数据

### 11.1 batch

```csv
batch_id,cage_id,species,stocking_date,initial_count,initial_avg_weight_g,initial_avg_length_cm,current_estimated_count,target_weight_g,target_date
BATCH_A,CAGE_03,large_yellow_croaker,2026-04-01,65000,10,8.5,63000,600,2026-10-30
BATCH_B,CAGE_05,large_yellow_croaker,2026-05-15,80000,8,7.9,79200,550,2026-11-15
```

### 11.2 body_measurements

```csv
batch_id,measurement_date,avg_weight_g,avg_length_cm,sample_count
BATCH_A,2026-04-01,10,8.5,100
BATCH_A,2026-05-01,42,12.8,120
BATCH_A,2026-06-01,120.5,18.2,120
```

### 11.3 water_quality

```csv
cage_id,timestamp,temperature_c,do_mg_l,salinity_ppt,ph,flow_m_s,turbidity_ntu
CAGE_03,2026-05-25T00:00:00,23.5,7.5,29.8,8.1,0.22,3.1
CAGE_03,2026-05-25T12:00:00,24.1,7.0,29.7,8.0,0.20,3.3
```

### 11.4 feeding_records

```csv
batch_id,date,feed_type,feed_amount_kg,feeding_times,feeding_note
BATCH_A,2026-05-30,starter_feed,520,3,normal
```

### 11.5 mortality_records

```csv
batch_id,date,mortality_count,reason
BATCH_A,2026-05-30,20,normal_loss
```

---

## 12. 前端设计

前端不要只做聊天框。V0 至少做一个“生产规划工作台”。

页面结构：

```text
左侧：批次选择 + 时间窗输入 + 目标规格/目标日期
中间：生产计划结果
右侧：智能体解释/聊天
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

本地前端环境变量：

```bash
NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8797
NEXT_PUBLIC_UI_PORT=3007
```

---

## 13. 部署脚本要求

Codex 请生成以下脚本，并确保脚本有清晰注释。

### 13.1 服务器启动脚本

文件：`deploy/server_start_tmux.sh`

功能：

```text
1. 进入项目目录
2. 创建或复用 tmux session aquaculture-agent-api
3. 在容器内启动 FastAPI
4. 绑定 127.0.0.1:8797，避免直接暴露公网
5. 日志写入 logs/backend.log
```

脚本环境变量：

```bash
PROJECT_DIR=${PROJECT_DIR:-$HOME/projects/aquaculture-agent}
TMUX_SESSION=${TMUX_SESSION:-aquaculture-agent-api}
BACKEND_PORT=${BACKEND_PORT:-8797}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-aquaculture-agent-backend:latest}
```

如果服务器支持 Docker：

```bash
docker run --rm \
  --name aquaculture-agent-api \
  -p 127.0.0.1:${BACKEND_PORT}:${BACKEND_PORT} \
  -v ${PROJECT_DIR}:/app \
  --env-file ${PROJECT_DIR}/.env \
  ${CONTAINER_IMAGE} \
  uvicorn backend.app:app --host 0.0.0.0 --port ${BACKEND_PORT}
```

如果服务器更适合 Apptainer：

```bash
apptainer exec \
  --bind ${PROJECT_DIR}:/app \
  ${PROJECT_DIR}/containers/aquaculture-agent-backend.sif \
  uvicorn backend.app:app --host 0.0.0.0 --port ${BACKEND_PORT}
```

Codex 应同时提供 Docker 和 Apptainer 文件，但 README 中说明优先按服务器实际环境选择一种。

### 13.2 本地 SSH 隧道脚本

文件：`deploy/local_tunnel.sh`

优先命令：

```bash
ssh -N -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} -J ${JUMP_HOST} ${REMOTE_HOST}
```

默认变量：

```bash
JUMP_HOST=lijiyao
REMOTE_HOST=gpu6000
LOCAL_PORT=8797
REMOTE_PORT=8797
```

如果上面不可用，README 中给出两步 fallback：

```bash
ssh -L 8797:127.0.0.1:8797 lijiyao
# 登录 lijiyao 后再确认 gpu6000 访问方式，按实际网络调整端口转发
```

### 13.3 本地前端启动脚本

文件：`deploy/local_start_frontend.sh`

内容要求：

```bash
conda activate rag_task
cd apps/web
npm install
npm run dev -- --port 3007
```

如果 `conda activate` 在非交互 shell 失败，脚本中要提示用户先执行：

```bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate rag_task
```

---

## 14. 环境变量

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
PLANNER_OPENAI_BASE_URL=http://127.0.0.1:8003/v1
PLANNER_OPENAI_MODEL=Llama-3.1-8B-Instruct

LOG_LEVEL=INFO
AGENT_DEBUG=true
```

说明：

1. `USE_LLM=false` 时，系统必须仍然可以生成生产计划。
2. `OPENAI_BASE_URL` 只是 OpenAI-compatible API 地址，不要在代码里绑定某个模型。
3. 未来如果接已有 vLLM 服务，只需要改 `.env`。

---

## 15. requirements.txt 建议

```text
fastapi==0.115.12
uvicorn==0.34.0
pydantic==2.11.3
pydantic-settings==2.8.1
numpy==1.26.4
pandas==2.2.3
scipy==1.15.2
matplotlib==3.10.1
orjson==3.10.16
python-dotenv==1.0.1
langchain==0.3.23
langchain-core==0.3.51
langchain-openai==0.3.12
langgraph==0.3.25
pytest==8.3.5
httpx==0.28.1
```

暂不把 R 依赖放入 V0 backend 镜像。R/MFPCA 在 V1 作为独立工具容器或异步任务接入。

---

## 16. Codex 首轮任务拆解

请 Codex 按以下顺序实现，不要一次写完所有高级功能。

### Task 0：初始化项目骨架

要求：

```text
1. 创建上述目录结构。
2. 创建 README.md、docs/ARCHITECTURE.md、docs/API.md、docs/DEPLOYMENT.md。
3. 创建 .env.example。
4. 创建 requirements.txt 和 pyproject.toml。
5. 创建基础测试目录。
```

验收：

```bash
find . -maxdepth 3 -type f | sort
```

### Task 1：实现 FastAPI 后端最小服务

要求：

```text
1. backend/app.py 实现 FastAPI app。
2. GET /health。
3. GET /api/batches。
4. GET /api/batches/{batch_id}/profile。
5. 从 CSV 读取 demo 数据。
```

验收：

```bash
uvicorn backend.app:app --host 127.0.0.1 --port 8797
curl http://127.0.0.1:8797/health
curl http://127.0.0.1:8797/api/batches
curl http://127.0.0.1:8797/api/batches/BATCH_A/profile
```

### Task 2：实现时间窗规范化

要求：

```text
1. 实现 normalize_planning_window。
2. 支持 planning_start/planning_end。
3. 支持 horizon_days。
4. 支持 target_weight_g/target_date。
5. 单元测试覆盖 future_plan、current_to_future、historical_review、target_backcast。
```

验收：

```bash
pytest backend/tests/test_window_normalization.py -q
```

### Task 3：实现工具层

要求：

```text
1. DatabaseQueryTool。
2. WaterQualityTool。
3. BiomassEstimationTool。
4. GrowthModelTool mock。
5. FeedingPlanTool。
6. RiskRuleTool。
```

验收：

```bash
pytest backend/tests/test_batch_profile.py backend/tests/test_growth_projection.py -q
```

### Task 4：实现 LangGraph 生产规划主流程

要求：

```text
1. graph/state.py 定义 AgentState。
2. graph/nodes/* 实现各节点。
3. graph/builder.py 构建 StateGraph。
4. POST /api/production/plan 调用图。
5. 返回结构化 JSON。
6. debug_trace 记录节点路径。
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
  }'
```

### Task 5：实现本地前端 V0

要求：

```text
1. apps/web 创建 Next.js 页面。
2. 左侧表单选择 batch_id、时间窗、horizon_days、目标规格。
3. 调用 /api/production/plan。
4. 展示 current_state、growth_prediction、weekly_plan、risk_assessment、action_items。
5. 不要求 UI 精美，但要可用。
```

本地验收：

```bash
conda activate rag_task
cd apps/web
npm install
npm run dev -- --port 3007
```

### Task 6：部署脚本

要求：

```text
1. deploy/backend.Containerfile。
2. deploy/backend.apptainer.def。
3. deploy/server_start_tmux.sh。
4. deploy/server_stop_tmux.sh。
5. deploy/server_logs.sh。
6. deploy/local_tunnel.sh。
7. deploy/local_start_frontend.sh。
8. docs/DEPLOYMENT.md 写清楚本地和服务器操作。
```

服务器验收：

```bash
ssh lijiyao
ssh gpu6000
cd ~/projects/aquaculture-agent
bash deploy/server_start_tmux.sh
bash deploy/server_logs.sh
curl http://127.0.0.1:8797/health
```

本地验收：

```bash
bash deploy/local_tunnel.sh
curl http://127.0.0.1:8797/health
bash deploy/local_start_frontend.sh
```

---

## 17. 生产规划算法 V0

V0 不追求模型科学完美，先追求工程闭环。

### 17.1 当前状态估算

```text
current_avg_weight_g = 最新体测记录平均体重
current_avg_length_cm = 最新体测记录平均体长
estimated_survival_count = batch.current_estimated_count 或 initial_count - mortality_sum
estimated_biomass_kg = current_avg_weight_g * estimated_survival_count / 1000
```

### 17.2 生长预测 mock

```text
base_daily_growth_rate = 根据当前体重阶段设定
temperature_factor = exp(-k * (temperature - optimal_temperature)^2)
do_factor = 1.0 if DO >= 6 else 0.85 if DO >= 5 else 0.65
adjusted_growth_rate = base_daily_growth_rate * temperature_factor * do_factor
```

可先用 Logistic：

```text
W_next = W + r * W * (1 - W / W_max)
```

默认：

```text
W_max = target_weight_g 或 600
optimal_temperature = 25
```

### 17.3 投喂计划 mock

```text
fish_size_stage:
  juvenile: W < 100g
  growout: 100g <= W < 400g
  pre_harvest: W >= 400g

feed_rate:
  juvenile: 3.0% - 5.0% biomass/day
  growout: 1.8% - 3.0% biomass/day
  pre_harvest: 1.0% - 2.0% biomass/day
```

注意：具体数值只作为 demo 假设，响应中必须写入 `assumptions`。

### 17.4 风险等级

```text
low: 无明显数据缺失，水质均值安全，目标可达
medium: 有轻微数据缺失、水质接近阈值或目标日期略紧
high: DO 低于阈值、体测过期、目标不可达或模型预测增长显著不足
```

---

## 18. 扩展性要求

Codex 写代码时必须遵守这些扩展性原则。

### 18.1 新模型通过 Model Adapter 接入

```python
class GrowthModelAdapter(Protocol):
    def predict(self, request: GrowthPredictionRequest) -> GrowthPredictionResult:
        ...
```

V0：`MockGrowthModelAdapter`

V1：`PatentFishiGrowthEcoAdapter`

V2：`ExternalModelServiceAdapter`

### 18.2 新工具通过 Tool Registry 接入

```python
class ToolRegistry:
    def register(self, name: str, tool: Any) -> None: ...
    def get(self, name: str) -> Any: ...
```

预留：

```text
WaterQualityMfpcaTool
DiseaseRiskTool
WeatherForecastTool
SalesPlanningTool
TraceabilityReportTool
```

### 18.3 新工作流通过 Graph Router 接入

未来增加：

```text
production_adjust_flow
sales_plan_flow
water_quality_warning_flow
traceability_report_flow
```

不要把这些提前塞进 V0 主流程，只保留 router 扩展点。

### 18.4 前端组件按业务卡片解耦

不要把所有响应渲染写在一个页面里。每个结果模块独立组件。

---

## 19. 不要做的事情

首轮不要做：

```text
1. 不要接真实数据库。
2. 不要强依赖 R/MFPCA。
3. 不要强依赖 LLM 才能生成计划。
4. 不要把销售规划塞进前期生产规划主接口。
5. 不要做复杂权限系统。
6. 不要在服务器上随便新增多个 tmux 会话和服务端口。
7. 不要把 SSH 私钥、API Key、服务器密码写进仓库。
8. 不要把所有业务逻辑写进 Prompt。
```

---

## 20. README 中必须写清楚的启动路径

### 20.1 本地开发后端

```bash
conda activate rag_task
pip install -r requirements.txt
uvicorn backend.app:app --host 127.0.0.1 --port 8797 --reload
```

### 20.2 本地开发前端

```bash
conda activate rag_task
cd apps/web
npm install
NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8797 npm run dev -- --port 3007
```

### 20.3 远端启动后端

```bash
ssh lijiyao
ssh gpu6000
cd ~/projects/aquaculture-agent
bash deploy/server_start_tmux.sh
```

### 20.4 本地连接远端后端

```bash
bash deploy/local_tunnel.sh
curl http://127.0.0.1:8797/health
```

### 20.5 本地启动前端访问远端后端

```bash
bash deploy/local_start_frontend.sh
```

---

## 21. Smoke Test

Codex 创建 `scripts/smoke_test.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
API_BASE=${API_BASE:-http://127.0.0.1:8797}

curl -fsS "$API_BASE/health" | python -m json.tool
curl -fsS "$API_BASE/api/batches" | python -m json.tool
curl -fsS "$API_BASE/api/batches/BATCH_A/profile" | python -m json.tool
curl -fsS -X POST "$API_BASE/api/production/plan" \
  -H 'Content-Type: application/json' \
  -d '{"batch_id":"BATCH_A","horizon_days":30,"target_weight_g":600,"target_date":"2026-10-30","use_llm":false}' \
  | python -m json.tool
```

---

## 22. Definition of Done

首轮项目搭建完成的标准：

```text
1. 后端 /health 可访问。
2. 能读取 demo batch 数据。
3. /api/production/plan 能对 BATCH_A 生成未来 30 天结构化计划。
4. 返回包含 debug_trace，能看到 LangGraph 节点执行路径。
5. 本地前端能通过 SSH 隧道访问远端后端。
6. 远端后端能在 gpu6000 用容器 + tmux 后台运行。
7. 所有端口、路径、模型地址都通过 .env 配置。
8. pytest 基础测试通过。
9. README 和 DEPLOYMENT 文档可照着操作。
10. 后续可以无痛接入 Patent_fishi.py 和 MFPCA_paper.R。
```

---

## 23. 给 Codex 的首条执行提示词

可以直接把下面这段给 Codex：

```text
请根据 docs 或本项目计划，初始化一个名为 aquaculture-agent 的项目。

核心目标：搭建“深远海养殖前期任意时段生产规划智能体”的最小可运行骨架。

硬性要求：
1. 后端使用 FastAPI + LangGraph + Pydantic。
2. 前端使用 apps/web 下的 Next.js + TypeScript。
3. 支持本地前端通过 SSH 隧道连接远端后端。
4. 后端预设运行在 gpu6000，容器 + tmux 后台启动。
5. 本地编译或启动前端时使用 conda rag_task 环境。
6. V0 数据层使用 CSV demo 数据。
7. V0 必须实现 GET /health、GET /api/batches、GET /api/batches/{batch_id}/profile、POST /api/production/plan。
8. POST /api/production/plan 支持 horizon_days、planning_start/planning_end、target_weight_g/target_date。
9. 不依赖 LLM 也能生成结构化生产计划。
10. 保留 Model Adapter、Tool Registry 和 Graph Router 扩展点，方便后续接入 Patent_fishi.py、MFPCA_paper.R、销售规划和水质预警。

请先完成项目骨架、demo 数据、后端 API、LangGraph 主流程、基础测试和部署脚本。不要先做复杂 UI、真实数据库、R/MFPCA 或销售规划。
```

---

## 24. 后续接入路线

完成 V0 后再做：

```text
V1：把 Patent_fishi.py 改造成 GrowthEcoSimulationTool，替换 mock growth model。
V2：加入生产过程调整 flow，支持实际生长 vs 预测生长偏差分析。
V3：把 MFPCA_paper.R 精简成独立 WaterQualityMfpcaTool，作为水质空间预警工具。
V4：加入销售规划 flow，把生产规划结果连接到上市窗口和生物资产评估。
V5：接真实生产数据库、时序数据库、网箱设备数据和模型服务。
```

---

## 25. 当前最优先的一件事

先把下面这条链跑通：

```text
本地前端输入 batch_id + 时间窗
  ↓ SSH 隧道
远端 FastAPI
  ↓ LangGraph
读取 demo 批次/水质/体测数据
  ↓ mock 生长预测
生成任意时间窗生产计划 JSON
  ↓
本地前端结构化展示
```

只要这条链稳定，后续接真实模型、真实数据和多智能体扩展都会比较顺。
