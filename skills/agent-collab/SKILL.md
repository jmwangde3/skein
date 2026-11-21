---
name: agent-collab
description: 两个或以上 Agent 要在同一个项目上并行推进独立任务、需要隔离工作树与协调合并时加载。只在并行期部署，并行结束就卸。触发：并行、双 agent、worktree、合并、并行拆子任务。
---

# agent-collab

## 只做这一件事

让两个 Agent 同时干活时不互相覆盖。**只在并行期部署，结束就卸**——留着等于每天为低频场景付上下文钱。

**不做**：日常记录（`task-checkpoint`）、顺序交接（`agent-handoff`）、建库（`project-memory`）。

## 开工前四步

下面命令里的 `<id-a>` / `<id-b>` 是占位符，执行前换成真实任务 ID。直接复制会报 `No such file or directory`——bash 会把 `<xx>` 当成读文件。

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }
STORE="$(kv store)"
WT_ROOT="$(kv worktree_root)"
[ -n "$STORE" ] && [ -n "$WT_ROOT" ] || { echo "[HANDOFF_GAP] 缺 store / worktree_root 键"; exit 1; }
WT="$WT_ROOT/$(basename "$PROJ")-worktrees"

# 1. 拆两个互不依赖的任务
bd -C "$STORE" create "子任务 A" -t task
bd -C "$STORE" create "子任务 B" -t task

# 2. 两个独立 worktree（不同路径 + 不同分支）
git -C "$PROJ" worktree add -b feat/task-a "$WT/task-a" HEAD
git -C "$PROJ" worktree add -b feat/task-b "$WT/task-b" HEAD

# 3. 每个 worktree 复制私有路由并核对忽略生效
for w in task-a task-b; do
  cp "$LOCAL" "$WT/$w/"
  git -C "$WT/$w" check-ignore -v AGENTS.local.md
done

# 4. 各自认领（不能与 --if-assignee 同用）
BEADS_ACTOR=agent-a bd -C "$STORE" update "<id-a>" --claim
BEADS_ACTOR=agent-b bd -C "$STORE" update "<id-b>" --claim
```

两个任务 ID 互不依赖才能并行。有依赖就串行，别硬拆。

## 并行中三条硬规则

- 各自只写自己的任务 ID 和**自己的**检查点文件（一任务一文件）
- **不同 agent 不同时改同一个未提交工作树**
- **KB 单写者**：开工前点名一个人写 `kb/`，另一人只写 `proposals/`。`worktree` 隔离不了 KB——KB 是另一个 git 仓，这是最容易漏的一条

## 合并只由集成者做

- 不许 `ours` / `theirs` 一键丢弃
- 冲突分级：同文件同段 → 人工处理；同文件不同段 → 自动合并后由负责 agent 验证语义；只读冲突 → 以写方为准，读方重读
- 输出冲突检查结果与未验证清单
- **代码没集成验收前不许 `bd close`**

## 收尾

```bash
# 1. 先合并：代码没进主分支，不许删 worktree
BASE="${BASE:-main}"     # 换成分支真名
git -C "$PROJ" checkout "$BASE"
git -C "$PROJ" merge --no-ff feat/task-a
git -C "$PROJ" merge --no-ff feat/task-b

# 2. 合并成功后清目录
git -C "$PROJ" worktree remove "$WT/task-a"
git -C "$PROJ" worktree remove "$WT/task-b"

# 3. skills-manager 装过才需要卸；手复制部署的直接删目录
SM="${SM:-$(command -v skills-manager-cli || echo "$HOME/.skills-manager/bin/skills-manager-cli.exe")}"
[ -x "$SM" ] && "$SM" projects undeploy --agent codex "$PROJ" agent-collab
```

`worktree remove` 遇到脏工作树会拒绝——那是在提醒你还有东西没合并，**不要用 `--force` 跳过**。

完整命令、冲突细则、合并检查清单在 `references/parallel.md`。

## 完成标志

两任务都 closed、改动都在主分支、worktree 已移除、`agent-collab` 已卸载。
