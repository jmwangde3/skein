# 接手与返场核对清单

适用于陌生 Agent 首次接手（A→B），以及原 Agent 返场继续（A→B→A）。
**返场方严禁沿用旧上下文记忆，必须按本清单重新核对。**

## 0. 项目接手（没有任务，或用户只说「让它接着干」）

任务接手从第 1 节开始。这里管另一种情况：**用户把一个已有项目交给你，没有具体任务**。

### 0.0 先认规则在哪

接手第一件事不是读任务，是确认这个工作区的规则都在哪。只有四层，缺哪层记「无」，不要补造：

| 层 | 文件 | 管什么 |
|---|---|---|
| a 全局 | `~/.workbuddy/agent-memory-snippet.md`（主本）→ 各客户端 `AGENTS.md` | 语言、编码、安全边界 |
| b 工作区 | `AGENTS.md` | 项目硬约束 |
| c 库 | `AGENTS.local.md` | 库路径与本工作区例外 |
| d 项目 | `<仓>/AGENTS.md` | 单个仓的约束 |

四条路径都要能说出来。检查点「规则在哪」一节与实际不符 → **以实际文件为准**，顺手把检查点改对。

先跑只读自检，省得靠眼睛找：

```bash
bash "<技能目录>/project-memory/scripts/check-rules.sh" "<工作区根>"
```

**发现第五个规则文件**（`RULES.md`、`CONVENTIONS.md`、`NOTES.md` 这类）→ 报 `[HANDOFF_GAP]`，先问用户归到哪一层，不要照着读。

### 0.1 先找档案

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
KB="$(kv kb)"; [ -n "$KB" ] || { echo "[HANDOFF_GAP] 缺 kb 键"; exit 1; }
REPO="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO" ] || { echo "[HANDOFF_GAP] 当前目录不在任何 git 仓里"; exit 1; }

# 工作区根自己就是仓根时，索引里的相对路径是 "."
REPO_N="$(cd "$REPO" && pwd -P)"
if [ "$REPO_N" = "$SCOPE" ]; then REL="."; else REL="${REPO_N#"$SCOPE"/}"; fi

grep -F "| \`$REL\` |" "$KB/facts/projects/INDEX.md" \
  || { echo "[HANDOFF_GAP] 索引里没有 $REL。可能扫库时这个仓还不存在，或工作区根指错了"; exit 1; }
```

拿到档案文件名后**只读那一份**，不要把 `projects/` 下所有档案一起读。

### 0.2 按状态决定动作

| 索引里的状态 | 你能做什么 | 不许做什么 |
|---|---|---|
| `READY` | 按档案定位入口、跑验证、等任务 | 把档案当事实：先核 HEAD 与工作树 |
| `PARTIAL` | 读档案，先补齐影响本次任务的缺口 | 假装缺口不存在 |
| `TODO` | 只做最小摸底（README + 目录两层），按 `project-memory/references/brief.md` 建档，再开工 | 直接改代码、宣称已经理解项目 |
| 索引里没有这个仓 | 报 `[HANDOFF_GAP]`，说明这是新仓 | 自己编一份档案顶上 |

### 0.3 六条冷启动规则

每份档案都不重复写这六条，它们只在这里：

1. 读档案 + 相关项目规则（`AGENTS.md`、`CONTRIBUTING.md` 之类）
2. 核对当前 `HEAD`、分支、`git status --short`；档案与现场冲突时**以现场为准**
3. 查任务库有没有正在进行的任务，有就读对应检查点
4. 有未明确归属的改动 → **不覆盖、不清理**，先问
5. 只读本次任务涉及的代码，不为了「熟悉项目」通读
6. 发现档案与现场冲突 → 先核实，顺手把档案改对

### 0.4 什么时候必须停

- 档案指向的仓不存在，或当前目录不在任何仓里
- `PARTIAL` 的缺口正好覆盖你要改的部分
- 工作树有未提交改动且没有任何记录
- 用户没说要做什么，却有人催你「开始」

停下时输出 `[HANDOFF_GAP]` + 你看到的原文，不要给推测。

---

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
