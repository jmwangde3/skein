---
name: agent-handoff
description: 要把任务交给另一个 Agent（handoff）、作为陌生或返场 Agent 接手（cold start / resume）、或交接中途出错需要恢复时加载。触发：交接、接手、换 Agent、冷启动、HANDOFF_GAP。
---

# agent-handoff

## 只做这一件事

让 A 停下的位置 B 能原样接上；A 回来时能接着 B 的进度。

**不做**：日常进度落盘（`task-checkpoint`）、并行分支合并（`agent-collab`）、建库（`project-memory`）。

## 交接只有两条合法路径

**路径 1：A 还活着**

1. 写最终检查点，`mode: HANDOFF_READY`，记全 `head` / `dirty_files` / `untracked_files`
2. `bd -C "$B" unclaim <id>`
3. **`unclaim` 成功后才通知 B。** 报错就重试，三次仍失败报 `[HANDOFF_GAP]`

**路径 2：A 已崩或失联**

等租约过期（300 秒），B 跑 `bd -C "$B" reclaim` 回收，再 `--claim` 接手。
这条路**不需要 A 做任何事，也不要求 A 的 `unclaim` 成功**——死掉的进程永远等不到回执。

**没有第三条。** A 没释放、租约也没过期，B 就 `--claim` 或直接改文件 = 抢占。判据是 `bd show <id>` 里的 `lease_expires_at`，不是「我觉得 A 应该停了」。

## 四条禁忌

- **不许抢占未过期任务**：看时间戳，不靠猜
- **A 复活后 `--if-assignee` 返回 exit 13 就停手**，不许抢回来
- **检查点说「干净」也不许 `git clean`**：先查来源
- **不许等人工点头**：检查点 / Beads / 代码现场三者能互相印证就开工；三者冲突且证据无法解释，才报 `[HANDOFF_GAP]`

## 接手方必须重跑核对

返场方（A→B→A 的 A）**严禁用旧对话记忆**。按 `references/receive.md` 走：

`bd show <id>` 核归属 → 读检查点 → 核 `git status --short` + `git rev-parse HEAD` → 只按「下一步」第 1 条开工

## 出错时

领取失败、rev 倒退、ID 对不上、现场文件消失 → 读 `references/recovery.md`，按现场特征查表，不要凭感觉处理。

## 完成标志

- 交出方：检查点落盘 + `unclaim` 成功（或已报 GAP）
- 接手方：`--claim` 成功 + 三方核对一致 + 检查点 `mode: RECEIVED`
