# Skein v2 架构设计说明

本文档记录 Skein v2 的核心架构取舍，供维护与二次改造参考。需求基线见 [`docs/requirements.md`](requirements.md)。

## 1. 第一性原理：工具代劳，人机分工

v1 的核心教训在于让 Agent 自己承担了过多“记账员”工作：每次落盘或接手都要跑一串 bash、手写 10 节长检查点、自己核对 `rev`、每 4 分钟续租。这既消耗本职工作的上下文与轮次，又导致实测中 Agent 经常漏写检查点。

v2 把职责一刀切开：
- **外部工具（0 Agent token）**：负责静默会话捕获（`ai-memory` Hook，默认 0 LLM）、机械状态汇总（`skein-cli` 单命令）、并行锁与看板（`kanban-md`）、大库混合检索（`qmd`）。
- **Agent（极少高价值语义）**：只在第一次改文件前用 1 条 `skein-cli mark` 立目标，在决策/约束/排除方案拐点补 1 行 `skein-cli note`，接手时跑 1 条 `skein-cli resume` 核对 6 项可验收清单。

## 2. 为什么是 5 个 Skill，而不是 4 个

v1 将“初次建库 + 建档 + 大知识库检索 + 规则审计”全部塞进 `project-memory`，导致不需要大知识库的小项目也必须背负全套上下文。

v2 拆分为严格互不重叠的 5 个 Skill，由人工通过 `skills-manager` 按需开关：
- `skein-init`：一次性挂载，建库与纳入范围活跃子项目最小建档，**建完即卸**。
- `task-checkpoint`：唯一全局常驻，压缩到 40 行以内，只守“写前留痕 + 拐点 1 行”。
- `agent-handoff`：项目级常驻可发现（未触发仅占约 50 tokens 元数据），兑现“A 零准备 + 用户在 B 说一句‘接手’直恢”。
- `kb-retrieval`：仅大型/复杂项目开启，小项目物理卸载；预留 `global_kb` 路由键以支持未来跨项目个人知识库。
- `agent-collab`：仅双 Agent 协作期开启，严格区分“模式 A：独立并行 worktree”与“模式 B：同任务单写者 + 只读观察者”，结束即卸。

## 3. 零准备接手与 6 项可验收恢复

不追求全量重放闲聊历史，而是以 **6 项可验收内容**（最后确认目标、变更约束、关键决定及理由、已排除方案、待验证假设、下一步）作为接手成功标准，并允许 B 重查中断前尚未形成结论的一小段探索。

底座实现采用“主方案 + 无缝降级”双层架构：
- **主方案**：`ai-memory`（Rust 单二进制，本地离线，默认 0 LLM，原生 Hook 覆盖 Claude Code / Codex / Antigravity / WorkBuddy）。日常仅开 Hook 捕获，**不常驻挂 MCP Server**，接手时通过 CLI 按需拉取，避免每轮工具定义 token 租金。
- **降级方案**（若 Native Windows 实测不稳且不走 WSL2）：客户端轻量 Stop/PreCompact Hook 自动落盘 + `cass` 按需检索本地 `.jsonl` 会话日志。`skein-cli resume` 统一封装底层差异，上层 5 个 Skill 无需修改。

## 4. 中断冲突 vs 有意实时配合

- **A 窗口开着但已停写**：允许 B 直接接手，不逼用户关闭 A。
- **A 仍有后台命令在写同一现场**：`skein-cli resume` 探测相关进程与 `.git/index.lock`，输出 `[WARN_BG_ACTIVE]`，要求 B 先汇报状态与产物并询问用户“等待或终止”。
- **双 Agent 有意实时配合**：必须挂载 `agent-collab` 并显式进入模式 B（A 唯一写者、B 只读观察者），与上述中断冲突严格区分。

## 5. 任务锁替换：为什么弃用 Dolt 版 Beads

原版 `gastownhall/beads` 已迁移至 Dolt 数据库且 issue 数量庞大，对单机本地双 Agent 协作过重。v2 解除对 Beads 的强绑定，日常单任务完全不需要任务数据库；仅在双 Agent 并行期选用纯 Markdown 单二进制 `kanban-md`（支持 `--compact` 省 token 输出、自动过期认领与 TUI）。
