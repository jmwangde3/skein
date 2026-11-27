---
name: agent-collab
description: 双 Agent 同时在同一项目上协作时启用（支持独立子任务并行与同任务实时配合两种模式）。仅协作期由人工通过 skills-manager 挂载，协作结束即卸载。触发：并行、双 agent、实时配合、worktree、合并。
---

# agent-collab

## 只做这一件事

让两个 Agent 在同一项目上同时干活时不互相覆盖。**仅在双人协作期挂载，结束立刻提醒用户通过 `skills-manager` 卸载。**

**不做**：单任务中途换人接手（`agent-handoff`）、日常单人记录（`task-checkpoint`）、建库（`skein-init`）。

## 开工前先选模式（严禁混用）

### 模式 A：独立子任务并行（各自改代码）
适用：两个子任务互不依赖，需同时修改代码/文档。

1. **任务认领（有 `kanban-md` 时用它防撞车）**：
   ```bash
   kanban-md add "子任务 A" --dir "$BOARD"
   kanban-md pick --claim --dir "$BOARD" --compact
   ```
   （未装 `kanban-md` 时，各自用独立任务 ID 与分支名隔离。）
2. **一键开独立工作树**（一任务一目录一分支）：
   ```bash
   skein-cli wt-add <task-a>
   skein-cli wt-add <task-b>
   ```
3. **三条硬规则**：
   - 严禁两个 Agent 同时修改同一个未提交工作树。
   - 知识库跨 worktree 共享：开工前点名唯一写者，另一方只写 `<kb>/proposals/`。
   - 合并只由集成者执行：不许 `ours`/`theirs` 盲丢；同文件同段冲突交人工；验证通过后再合并。
4. **安全收尾**：
   合入主分支并验证通过后，运行 `skein-cli wt-clean <task-a>`（遇到脏树会拒绝，绝不用 `--force` 强删），然后提醒用户卸载 `agent-collab`。

### 模式 B：同任务实时配合（单写者 + 只读观察者）
适用：如 A 负责写代码，B 实时做代码审查、跑测试或查文档，需要观察**同一份未提交现场**。

1. **不开 worktree**，共享当前工作树。
2. **显式锁定写权限**：
   - **唯一写者（A）**：拥有源码与当前任务锚点的写权限。
   - **只读观察者（B）**：严禁修改任何源码文件；审查结论、测试报告或修改建议仅输出到对话或 `<kb>/proposals/<日期>-review-<主题>.md`。
3. **与中断冲突严格区分**：若 A 并非显式配合、而是意外残留后台写入命令占用现场，属于单任务中断冲突，归 `agent-handoff` 处理，不得按本模式强行介入。

完整冲突分级与合并核对清单见 `references/parallel.md`。

## 完成标志

- 模式 A：改动已合入主分支、验证通过、worktree 已安全清理、看板任务已关闭。
- 模式 B：审查/测试结论已交付且未污染源码。
- 两种模式结束时均须提醒用户：**通过 `skills-manager` 卸载 `agent-collab`**。
