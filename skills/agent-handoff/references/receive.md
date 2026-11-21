# 接手与返场核对清单

适用于陌生 Agent 首次接手（A→B），以及原 Agent 返场继续（A→B→A）。
**返场方严禁沿用旧上下文记忆，必须按本清单重新核对。**

## 1. 取得合法租约

```bash
bd -C "$B" show <id>
```

| 看到什么 | 动作 |
|---|---|
| assignee 为空 | 直接 `bd -C "$B" update <id> --claim`（先设好 `BEADS_ACTOR`） |
| assignee 是别人，`lease_expires_at` **已过期** | 先 `bd -C "$B" reclaim`，再 `--claim` |
| assignee 是别人，租约**未过期** | 停手，不许抢 |
| assignee 是自己，租约还有效 | 断线重入，不是接手。先 `heartbeat` 续上，再核对现场，**不要重新 claim** |

**`reclaim` 会回收库里所有过期租约，不只是你手上这一个。** 执行后必须再 `show` 一次确认目标任务的真实归属——`reclaim` 成功不等于你领到了。

## 2. 三方交叉核对

读检查点 `<checkpoints>/<task_id>.md`（`<checkpoints>` 取自项目根 `AGENTS.local.md` 的 `checkpoints` 键，缺键即报 `[HANDOFF_GAP]`），然后在 `worktree` 路径下核对：

**ID 核对**
检查点 YAML 里的 `task_id` 必须与手上的 `<id>` 完全一致。

**提交核对**

```bash
git -C "<worktree>" rev-parse HEAD
```

与检查点 `head` 比对。不一致就看 `git log -n 5 --oneline` 和 Beads `notes`，确认是不是前任留下的合法新提交。解释不了 → 停手报 `[HANDOFF_GAP]`。

**工作树核对**

```bash
git -C "<worktree>" status --short
```

逐项对检查点的 `dirty_files` 与 `untracked_files`。

- 共用工作树接力时，**保留前任留下的合法脏文件**
- 即使检查点写「干净」，只要 `git status --short` 有输出就**绝不直接清理**，先查来源
- 出现检查点没记录、日志也解释不了的修改 → 停手报 `[HANDOFF_GAP]`

## 3. 确认接手并开工

三方印证无误后，按 `task-checkpoint` 的三层协议更新检查点：

- `mode` → `RECEIVED`（开工后改 `ACTIVE`）
- `writer` → 当前 `$BEADS_ACTOR`
- `checkpoint_rev` → 原值 + 1

然后**只从「下一步（可直接执行）」第 1 条开始**，并遵守「不要重复」里的避坑记录。

## 4. 什么情况下必须先停下来问

只有这四种，其余一律自己走下去：

1. 检查点的 `task_id` 与手上的任务 ID 不一致
2. `git status` 里有检查点未记录、也无法从日志解释的修改
3. 检查点指向的 worktree 或文件不存在
4. 任务归属与租约状态矛盾（如 assignee 是自己但 `show` 说已被 reclaim）

停下时输出 `[HANDOFF_GAP]`，把看到的两边内容原样贴出来，不要给推测。
