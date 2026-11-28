---
name: task-checkpoint
description: 单 Agent 长任务日常留痕：写前最小记录与关键语义锚点补记。日常唯一全局常驻技能，极省 token。触发：长任务开工、写前留痕、关键决策、排除方案、收尾。
---

# task-checkpoint

## 只做这一件事

在**不拖慢本职工作**的前提下，用最短的外部命令留住“做到哪、别重复什么、下一步”。机械现场与会话轨迹交由外部 Hook（如 `ai-memory`）自动捕获，**绝不手写长篇检查点或手动维护 YAML**。

**不做**：跨助手接手（`agent-handoff`）、大知识库检索（`kb-retrieval`）、并行协作（`agent-collab`）、建库（`skein-init`）。

## 两条铁律

1. **写前最小留痕**：除末尾的小改动例外，可能留下半成品的工作，在**第一次实质修改文件或启动长耗时命令前**，执行 1 条命令立锚点：
   ```bash
   skein-cli mark --goal "<用户最后确认的目标>" --constraint "<关键约束，无则省>" --next "<当前第一步>"
   ```
   同目标重复 `mark` 复用已有锚点。目标变更用 `note --type goal`，独立新任务用新 `--id`。
2. **仅在语义拐点补 1 行**：只有出现以下 5 类高价值事件时，才执行 1 条 `note`（其余常规步骤完全跳过，不记流水账）：
   ```bash
   skein-cli note --type <goal|constraint|decision|excluded|hypothesis|next> "<一句话结论与理由>"
   ```
   - `goal` / `constraint`：用户修改了目标或新增约束
   - `decision`：做出会推翻旧做法的关键决定及理由
   - `excluded`：验证失败并排除某方案（防止后续重复踩坑）
   - `hypothesis`：提出尚未验证的关键假设
   - `next`：阶段完成、遇阻或收尾时更新下一步

## 收尾与归档

- 阶段停下或用户说“先到这 / 明天继续”：更新一条 `--type next`，回复末尾附任务 ID 即可。
- 任务彻底验收关闭：`skein-cli close <task_id>`。
- 一次可完成、易于重做且没有待交接决定的小改动，可直接处理，零次 Skein 专用调用。
