---
name: skein-init
description: 给新工作区建库、初始化 Git 与目录骨架、为纳入范围的活跃子项目写最小档案。仅建库或新增子项目时通过 skills-manager 挂载，建完即卸载。触发：建库、初始化工作区、新项目接入、建档。
---

# skein-init

## 只做这一件事

完成工作区建库，并为**用户确认纳入范围的活跃子项目**各写一份 ≤2 KB 的最小项目档案。**建完立刻提醒用户通过 `skills-manager` 卸载本技能。**

**不做**：日常进度记录（`task-checkpoint`）、接手恢复（`agent-handoff`）、大知识库检索（`kb-retrieval`）、并行协作（`agent-collab`）。

## 三步流程

1. **跑单命令建骨架**：
   ```bash
   skein-cli init --workspace "<工作区根>" --data "<数据家，默认 ~/skein-data>"
   ```
   若为纯文档/调研工作区且尚无任何 Git 仓，加 `--git-init` 统一纳入 Git 管理。
2. **确认活跃子项目范围**：
   读 `<kb>/facts/projects/INDEX.md`。
   - 仅 1 个仓 → 直接建档。
   - 多个子仓 → 列清单问用户**哪些纳入活跃范围**（排除归档/无关目录）；**所有经确认纳入范围的子项目**都必须具备最小档案。
3. **写最小档案（每仓 ≤2 KB / 40 行）**：
   详细契约与内容哈希巡检规则见 `references/brief.md`。每份档案只写 5 块并标来源（`[源码]` / `[文档]` / `[推断]`）：
   - 头部：状态（`READY`/`PARTIAL`）、相对路径、基线 HEAD、巡检文件哈希（`git hash-object` 前 8 位）、建档时间
   - 定位（1 句）
   - 入口（最多 3 条真实路径）
   - 运行/验证命令（标明是否实测）
   - 关键文档指针（如 `AGENTS.md`）与缺口

## 完成标志

- `skein-cli check` 全绿
- 所有纳入范围的子项目在 `INDEX.md` 中均为 `READY`（或带明确缺口的 `PARTIAL`）且已提交进 `<kb>`
- 回复末尾提醒用户：**通过 `skills-manager` 卸载 `skein-init`**
