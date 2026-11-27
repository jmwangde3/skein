# Changelog

## v2.0.0 (2026-11-27)

### 架构升级
- **工具代劳原则落地**：新增 `bin/skein-cli` 单命令封装层，取代原来让 Agent 手动拼装多步 bash 核对与 10 节长检查点的低效流程。
- **4 Skill 拆分为 5 Skill**：将原 `project-memory` 拆分为一次性建库技能 `skein-init` 与大知识库专用技能 `kb-retrieval`，小项目不再承担大知识库上下文成本。
- **零准备接手与 6 项可验收标准**：`agent-handoff` 改为项目级常驻可发现（未触发仅占约 50 tokens 元数据），支持 A 零准备 + 用户在 B 说一句“继续”直接恢复唯一未完任务，并内置后台写入进程冲突检测与 6 项可验收恢复清单。
- **双模式协作**：`agent-collab` 新增“同任务实时配合（单写者 + 只读观察者）”模式，与“独立子任务并行（worktree）”及“后台命令残留冲突”严格区分。
- **外部工具栈轻量化**：解除对已迁移到 Dolt 的重型 `gastownhall/beads` 强依赖，改用单二进制 `kanban-md`（并行期按需）+ `ai-memory`（静默 Hook 捕获，默认 0 LLM，含 Hook+`cass` 降级口）。

### 缺陷修复
- 清除原 `project-memory/SKILL.md`、`init.sh`、`check-rules.sh` 中硬编码的个人本机路径（`H:\AI工作区\...`、`~/.workbuddy/agent-memory-snippet.md`）。
- 修正 `templates/global-rules.md` 中已过时且与 `design.md` 冲突的 `60%–75%` 上下文触发文案。
- 移除 `agent-collab` 中写死的 `--agent codex` 自动卸载命令，统一改为人工通过 `skills-manager` 开关、Agent 仅提醒。
