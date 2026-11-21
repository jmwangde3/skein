# 接手与返场核对清单

适用于陌生 Agent 首次接手（A→B），以及原 Agent 返场继续（A→B→A）。
**返场方严禁沿用旧上下文记忆，必须按本清单重新核对。**

## 1. 取得合法租约

先把两个路径解析出来——**从当前目录向上找作用域根**，不要假设自己在仓根：

```bash
SCOPE=""
d="$(pwd -P)"
while :; do
  if [ -f "$d/AGENTS.local.md" ]; then SCOPE="$d"; break; fi
  p="$(dirname "$d")"
  if [ "$p" = "$d" ]; then break; fi
  d="$p"
done
[ -n "$SCOPE" ] || { echo "[HANDOFF_GAP] 没找到 AGENTS.local.md（应在工作区根）"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$SCOPE/AGENTS.local.md" | head -n 1 | tr -d '\r'; }
B="$(kv store)"; CKPT="$(kv checkpoints)"
[ -n "$CKPT" ] || { echo "[HANDOFF_GAP] 缺 checkpoints 键"; exit 1; }
```

任务库是**整个工作区共用**的，`B` 为空说明没配 Beads，走纯文件模式（见第 6 节）。

```bash
[ -n "$B" ] && bd -C "$B" show "<id>"
```

| 看到什么 | 动作 |
|---|---|
| assignee 为空 | 直接 `bd -C "$B" update "<id>" --claim`（先设好 `BEADS_ACTOR`） |
| assignee 是别人，`lease_expires_at` **已过期** | 先 `bd -C "$B" reclaim`，再 `--claim` |
| assignee 是别人，租约**未过期**，用户已让 A 停下并授权 B 接手 | 按下面的转派命令做，**不要直接 `--claim`** |
| assignee 是别人，租约**未过期**，A 可能还在写 | 只读。请用户先停 A，或按 `agent-collab` 开独立 worktree |
| assignee 是自己，租约还有效 | 断线重入，不是接手。先 `heartbeat` 续上，再核对现场，**不要重新 claim** |

用户已授权、且 A 已停止时，B 执行（`B` 是 store 路径，`TASK_ID` 是真实任务 ID）：

```bash
[ -n "${B:-}" ] && [ -n "${TASK_ID:-}" ] && [ -n "${BEADS_ACTOR:-}" ] \
  || { echo "[HANDOFF_GAP] 缺 store / TASK_ID / BEADS_ACTOR"; exit 1; }

bd -C "$B" update "$TASK_ID" --force -a "$BEADS_ACTOR" || exit $?   # 转派
bd -C "$B" update "$TASK_ID" --claim || exit $?                     # 确认归自己
bd -C "$B" heartbeat "$TASK_ID" || exit $?                          # 续租
bd -C "$B" show "$TASK_ID"                                          # 回读确认
```

`--force` 不自动续租，所以后面三步不能省。**转派不是终止命令**——它只改任务归属，A 已经发出的命令照样会执行完。

**`reclaim` 会回收库里所有过期租约，不只是你手上这一个。** 执行后必须再 `show` 一次确认目标任务的真实归属——`reclaim` 成功不等于你领到了。

## 2. 三方交叉核对

读检查点 `$CKPT/<task_id>.md`，**先在检查点里定出「该去哪个目录核对现场」**，再动手核对。一个工作区可能有好几个仓，站错仓就会把「正常的另一个仓」误判成现场不一致。

```bash
# 1) 并行任务：检查点写了 worktree，且目录还在
# 2) 单线任务：worktree 为空，用检查点的 repo
# 3) repo 明确写了 none：当时不在任何 git 仓里，跳过 Git 核对
# 4) 老检查点没有 repo 字段：只能按当前目录判断
WT="$(sed -n 's/^worktree:[[:space:]]*//p' "$CKPT/<task_id>.md" | head -n 1 | tr -d '\r')"
RP="$(sed -n 's/^repo:[[:space:]]*//p'     "$CKPT/<task_id>.md" | head -n 1 | tr -d '\r')"

if [ -n "$WT" ] && [ -d "$WT" ]; then
  HERE="$WT"
elif [ -n "$WT" ]; then
  echo "[HANDOFF_GAP] 检查点写了 worktree，但目录不存在：$WT"
  echo "先确认并行分支是否已合并；不要默默换到别的仓继续"
  HERE=""
elif [ -n "$RP" ] && [ "$RP" != none ]; then
  HERE="$RP"
elif [ "$RP" = none ]; then
  HERE=""
else
  HERE="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
fi
```

`HERE` 与你当前所在的仓不是同一个时，**先确认自己有没有站错目录**，不要在错的仓里得出「现场不一致」的结论。`HERE` 为空表示这份检查点本来就没有 Git 现场，跳过下面两步提交/工作树核对。

**文件头核对**

| 字段 | 合格标准 | 不合格怎么办 |
|---|---|---|
| `schema_version` | 等于 1 | 版本不认识 → 停手报 `[HANDOFF_GAP]`，不要按自己的理解硬读 |
| `task_id` | 与手上的 `<id>` 完全一致 | 停手 |
| `checkpoint_rev` | 是正整数 | 缺失或不是数字 → 文件被截断过，停手 |
| `mode` | 正常交棒为 `HANDOFF_READY`；主动接管可以是 `ACTIVE` | `ACTIVE` 说明没有最终快照：按 Git 现场恢复，「下一步」可能过时；对不上就报 `[HANDOFF_GAP]` |
| `repo` | 绝对路径，或 `none`（当时不在任何仓里） | 路径在本机不存在 → 换机器或换盘了：按当前所在的仓重新核对，并把这个差异写进检查点；不许当作一致 |

**ID 核对**
检查点 YAML 里的 `task_id` 必须与手上的 `<id>` 完全一致。

**提交核对**

```bash
git -C "$HERE" rev-parse HEAD
```

与检查点 `head` 比对。不一致就看 `git log -n 5 --oneline` 和 Beads `notes`，确认是不是前任留下的合法新提交。解释不了 → 停手报 `[HANDOFF_GAP]`。

**工作树核对**

```bash
git -C "$HERE" status --short
```

逐项对检查点的 `dirty_files` 与 `untracked_files`。`git status --short` 里前两列是 `??` 的算未跟踪，其余算已修改。

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

以下情况必须停手，其余在核对通过后继续：

1. 检查点的 `task_id` 与手上的任务 ID 不一致
2. `git status` 里有检查点未记录、也无法从日志解释的修改
3. 检查点指向的 worktree 或文件不存在
4. 任务归属与租约状态矛盾（如 assignee 是自己但 `show` 说已被 reclaim）
5. A 可能仍在写共享工作树或检查点
6. `ACTIVE` 快照与 Git 现场的差异解释不了

停下时输出 `[HANDOFF_GAP]`，把看到的两边内容原样贴出来，不要给推测。
