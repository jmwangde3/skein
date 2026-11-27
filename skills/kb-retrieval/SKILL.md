---
name: kb-retrieval
description: 大型复杂项目按需检索知识库、回读历史决策原文、写回长期事实/决策与整理索引。仅大型/复杂项目通过 skills-manager 按需启用，小型项目永不挂载。触发：查知识库、历史决策、写回知识、整理知识库、qmd。
---

# kb-retrieval

## 只做这一件事

在**绝不全量加载**的前提下，从项目知识库（及可选的跨项目个人知识库）精准抽出当前所需的那一页，并把经验证的新事实与架构决策写回离线 Git 知识库。

**不做**：工作区建库（`skein-init`）、任务进度留痕（`task-checkpoint`）、接手恢复（`agent-handoff`）、并行隔离（`agent-collab`）。

## 按需检索阶梯（命中即停，从便宜到贵）

先从工作区根 `AGENTS.local.md` 读取 `kb`（若未来启用跨项目知识库，同时读取可选键 `global_kb`）：

1. **索引定位**：只读 `<kb>/INDEX.md`，定位到 1–2 个目标文件。
2. **关键词直查**：`rg -n "<术语/错误码>" "$KB/facts" "$KB/decisions" "$KB/runbooks"`（跳过 `archive/` 与 `proposals/`）。
3. **外部离线检索**：
   - 若已装 `ai-memory`：`ai-memory search "<查询词>"`（默认 0 LLM，融合 FTS + 实体 + 链接）。
   - 若文档超 50 篇且已装 `qmd`：`qmd search "<词>" -c skein-kb -n 5` → `qmd get <file>:<from>:<count>` → 模糊概念才用 `qmd vsearch`。

**禁止**：整份 `cat` 长文件、一次拉回几十条结果、把 `projects/` 下所有子项目档案一起加载。

## 写回与单写者规则

- 只写长期有效内容：硬事实进 `facts/`、方案决策及理由进 `decisions/`、可复用操作进 `runbooks/`；临时任务进度不进知识库。
- **并发期单写者**：双 Agent 协作时仅指定写者直写 `<kb>`，另一方只写 `<kb>/proposals/<日期>-<子项目>-<主题>.md`（附证据），由写者核实后合并提交。
- 每次写回必须 `git -C "$KB" add -- <限定文件> && git -C "$KB" commit --only -m "kb: <摘要>"`，且确认 `git -C "$KB" remote` 为空（纯离线）。

检索命令细节与索引整理阈值见 `references/search.md`。
