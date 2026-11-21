# 并行协作完整操作与合并清单

## 路径常量

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -1 | tr -d '\r'; }
STORE="$(kv store)"
CKPT="$(kv checkpoints)"
KB="$(kv kb)"
WT="$(kv worktree_root)/$(basename "$PROJ")-worktrees"
[ -n "$STORE" ] && [ -n "$CKPT" ] && [ -n "$KB" ] && [ -n "$WT" ] \
  || { echo "[HANDOFF_GAP] 缺 store / checkpoints / kb / worktree_root 键"; exit 1; }
```

路径全部来自项目根 `AGENTS.local.md`，缺文件或缺键就停，**不要用默认值或推测路径补齐**。

## 1. 开工

```bash
# 拆任务
bd -C "$STORE" create "子任务 A" -t task
bd -C "$STORE" create "子任务 B" -t task

# 建 worktree（路径与分支都不同）
git -C "$PROJ" worktree add -b feat/task-a "$WT/task-a" HEAD
git -C "$PROJ" worktree add -b feat/task-b "$WT/task-b" HEAD

# 私有路由复制 + 忽略核对
for w in task-a task-b; do
  cp "$LOCAL" "$WT/$w/"
  git -C "$WT/$w" check-ignore -v AGENTS.local.md
done

# 各自认领
BEADS_ACTOR=agent-a bd -C "$STORE" update <id-a> --claim
BEADS_ACTOR=agent-b bd -C "$STORE" update <id-b> --claim
```

`AGENTS.local.md` 用 `info/exclude` 排除，worktree 有独立的 `info/exclude`，**每个 worktree 都要单独加一次忽略规则**，否则 `ls-files` 会把它带进来。

## 2. 并行中

租约 300 秒。长任务每 ≤4 分钟 `bd -C "$STORE" heartbeat <id>`，过期会被 `reclaim` 收走。

```bash
# 各自独立检查点
$CKPT/<id-a>.md    # agent-a 只写这个
$CKPT/<id-b>.md    # agent-b 只写这个
```

**不要两个人写同一个 `kb/` 文件。** 非写者把结论写进 `proposals/`：

```
proposals/20261121-worktree-naming.md
改哪个文件：facts/agent-env.md
改什么：补一条 worktree 命名约定
为什么：两个 agent 用了不同前缀，合并时混淆
证据：git worktree list 输出
```

## 3. 冲突分级

| 级别 | 情形 | 处理 |
|---|---|---|
| 同文件同段 | Git 报冲突，或同一逻辑块双边改 | 停下，人工处理。不许猜 |
| 同文件不同段 | 自动合并成功 | 合并后**由负责 agent 跑测试**再提交。Git 不报错 ≠ 语义对 |
| 只读冲突 | 一方改了另一方正在引用的接口/文档 | 以写方为准，读方重读最新内容再继续 |

## 4. 合并检查清单

- [ ] 两分支各自任务已完成，没跨区改对方工作树
- [ ] 检查点与任务 ID 对应清晰，无串写
- [ ] `kb/` 变更遵守单写者（非写者走了 `proposals/`，写者已 commit）
- [ ] 集成者逐项合并，未用 `ours` / `theirs`
- [ ] 已输出冲突检查结果与未验证清单
- [ ] 集成验收通过后才 `bd -C "$STORE" close <id> --reason "证据"`
- [ ] worktree 已移除
- [ ] `agent-collab` 已卸载

## 5. 收尾

```bash
git -C "$PROJ" worktree remove "$WT/task-a"
git -C "$PROJ" worktree remove "$WT/task-b"
git -C "$PROJ" worktree prune

SM="${SM:-$(command -v skills-manager-cli || echo "$HOME/.skills-manager/bin/skills-manager-cli.exe")}"
[ -x "$SM" ] && "$SM" projects undeploy --agent codex "$PROJ" agent-collab
```

`worktree remove` 遇到脏工作树会拒绝。先确认那些改动是要保留还是要丢弃——**不要用 `--force` 跳过判断**。
