---
name: agent-handoff
description: 要把任务交给另一个 Agent（handoff）、作为陌生或返场 Agent 接手（cold start / resume）、或交接中途出错需要恢复时加载。触发：交接、接手、换 Agent、冷启动、HANDOFF_GAP。
---

# agent-handoff

## 只做这一件事

让 A 停下的位置 B 能原样接上；A 回来时能接着 B 的进度。

**不做**：日常进度落盘（`task-checkpoint`）、并行分支合并（`agent-collab`）、建库（`project-memory`）。

## 先判：要不要写 handoff

| 场景 | 写什么 |
|---|---|
| 同一个 agent 新开会话 / 换天 / 重启 | **检查点**，不写 handoff |
| 换另一个 agent、换机器、换人 | handoff |
| 用户说「写 handoff」但没说交给谁 | **检查点**，回复里报路径；点名了接手方或明确要文件才写 handoff |

handoff 只解决「接手的人看不到你的上下文」；同一 agent 的下一轮读检查点就够，写 handoff 是重复。

## 接手由 B 发起，A 不必交棒

用户说「让 B 接手」时，**A 不需要先写检查点、不需要 `unclaim`、不需要通知任何人**。B 自己看现场决定动作：

| 现场（`bd -C "$B" show "$TASK_ID"`） | B 的动作 |
|---|---|
| 没人认领 | `bd -C "$B" update "$TASK_ID" --claim` |
| 租约已过期 | `bd -C "$B" reclaim`，再 `--claim` |
| 租约有效，用户已让 A 停下 | `bd -C "$B" update "$TASK_ID" --force -a "$BEADS_ACTOR"` 转派，再 `--claim`、`heartbeat` |
| 租约有效，A 可能还在写 | **只读**。请用户先停 A；或两人都要继续 → 走 `agent-collab` 开独立 worktree |

**授权不等于确认 A 已停。** `--force` 只改任务归属，**不会终止 A 已经发出的命令**，也不保护工作树、检查点和知识库。所以「用户让我接」+「A 还在跑」两件事同时成立时，B 不许在同一棵树里落笔。

A 自愿交棒（写 `HANDOFF_READY` 再 `unclaim`）仍然更完整、更省事，但那是**快捷路径，不是 B 接手的前置条件**。

**没有 `bd` 时**：只有文件快照，没有归属栅栏。确认 A 不再写才能顺序接手；确认不了就停在只读并报 `[HANDOFF_GAP]`——纯文件模式没有自动互斥。

## 四条禁忌

- **没有用户的接管指令，不许动别人的有效租约**：`--force` 只在「用户要求 B 接手」时用，其余情况看时间戳
- **A 复活后 `--if-assignee` 返回 exit 13 就停手**，不许抢回来
- **检查点说「干净」也不许 `git clean`**：先查来源
- **不许无故等人工点头**：三方印证一致就开工；冲突且证据解释不了，才报 `[HANDOFF_GAP]`

## 接手方必须重跑核对

返场方（A→B→A 的 A）**严禁用旧对话记忆**。先分清接的是哪一种：

| 用户说 | 接的是什么 | 从哪开始 |
|---|---|---|
| 「接手这个任务」「A 做一半了」 | **任务**：有 id、有检查点 | `references/receive.md` 第 1 节 |
| 「接手这个项目」「让它接着干」 | **项目**：可能没有任务 | `references/receive.md` 第 0 节 |
| 两样都没说清 | 先问一句，不要猜 | — |

**项目接手的核心是读档案，不是读源码。** 档案在 `facts/projects/<仓名>.md`（由 `project-memory` 建档）；没有档案或状态是 `TODO` → 现场只做最小摸底，并在开工前补建档，不要假装已经理解项目。

任务接手的核对顺序：

`bd show <id>` 核归属 → 读检查点 → 在检查点 `worktree`（为空则 `repo`；两者都没有说明当时不在仓里）核对 `git status --short` + `git rev-parse HEAD` → 只按「下一步」第 1 条开工

主动接管拿到的可能是 `mode: ACTIVE` 的半截快照，**「下一步」可能已经过时**，先对着 Git 现场核实再执行。

## 出错时

领取失败、rev 倒退、ID 对不上、现场文件消失 → 读 `references/recovery.md`，按现场特征查表，不要凭感觉处理。

## 完成标志

- B 主动接手：领取或转派后 `show` 确认归属是 B + 已确认 A 停止 + 三方核对一致 + 检查点 `mode: RECEIVED`
- A 自愿交出：检查点落盘 + `unclaim` 成功（或已报 `[HANDOFF_GAP]`）
