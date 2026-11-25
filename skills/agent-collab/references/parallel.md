# 并行协作完整操作与合并清单

## 路径常量

```bash
# 工作区根：从当前目录向上找第一个含 AGENTS.local.md 的目录
SCOPE=""
d="$(pwd -P)"
while :; do
  if [ -f "$d/AGENTS.local.md" ]; then SCOPE="$d"; break; fi
  p="$(dirname "$d")"
  if [ "$p" = "$d" ]; then break; fi
  d="$p"
done
[ -n "$SCOPE" ] || { echo "[HANDOFF_GAP] 没找到 AGENTS.local.md（应在工作区根）"; exit 1; }
LOCAL="$SCOPE/AGENTS.local.md"
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }

# 并行作用在"当前所在的代码仓"，不是整个工作区
REPO="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO" ] || { echo "[HANDOFF_GAP] 当前目录不在 git 仓里，开不了 worktree"; exit 1; }
STORE="$(kv store)"
CKPT="$(kv checkpoints)"
KB="$(kv kb)"
WT_ROOT="$(kv worktree_root)"
[ -n "$STORE" ] && [ -n "$CKPT" ] && [ -n "$KB" ] && [ -n "$WT_ROOT" ] \
  || { echo "[HANDOFF_GAP] 缺 store / checkpoints / kb / worktree_root 键"; exit 1; }
# 不同父目录下的同名仓会算出同一个目录，用仓路径的短 hash 区分
hash8() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; }
WT="$WT_ROOT/$(basename "$REPO")-$(printf '%s' "$REPO" | hash8 | cut -c1-8)-worktrees"
```

路径全部来自**工作区根**的 `AGENTS.local.md`（从当前目录向上找到的第一个），缺文件或缺键就停，**不要用默认值或推测路径补齐**。`worktree` 开在当前所在的代码仓上，不是整个工作区。

## 1. 开工

`<id-a>` / `<id-b>` 是占位符，换成第 1 步建出来的真实任务 ID。直接复制会把 `<` 当重定向。

```bash
# 拆任务
bd -C "$STORE" create "子任务 A" -t task
bd -C "$STORE" create "子任务 B" -t task

# 建 worktree（路径与分支都不同）
git -C "$REPO" worktree add -b feat/task-a "$WT/task-a" HEAD
git -C "$REPO" worktree add -b feat/task-b "$WT/task-b" HEAD

# 私有路由复制到各 worktree，并确认忽略规则管得住它
for w in task-a task-b; do
  cp "$LOCAL" "$WT/$w/AGENTS.local.md"
  git -C "$WT/$w" check-ignore -v AGENTS.local.md
done

# 各自认领
BEADS_ACTOR=agent-a bd -C "$STORE" update "<id-a>" --claim
BEADS_ACTOR=agent-b bd -C "$STORE" update "<id-b>" --claim
```

`AGENTS.local.md` 靠仓库根的 `.gitignore` 排除（写 `/AGENTS.local.md`）。`.gitignore` 随仓库走，linked worktree 共用主仓的索引与忽略规则，所以主仓加过一次就够，不用每个 worktree 再加一遍。上面的 `cp` 是把路由文件本身带进 worktree（技能要靠它读路径），`check-ignore` 是确认它不会被 `git add` 带进去。

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
# 1. 先合并。集成分支真名以项目为准
BASE="${BASE:-main}"
git -C "$REPO" checkout "$BASE"
git -C "$REPO" merge --no-ff feat/task-a
git -C "$REPO" merge --no-ff feat/task-b

# 2. 确认两支都已进主分支（下面每条都要有输出）
git -C "$REPO" merge-base --is-ancestor feat/task-a "$BASE" && echo "task-a 已集成"
git -C "$REPO" merge-base --is-ancestor feat/task-b "$BASE" && echo "task-b 已集成"

# 3. 合并成功后才清目录
git -C "$REPO" worktree remove "$WT/task-a"
git -C "$REPO" worktree remove "$WT/task-b"
git -C "$REPO" worktree prune

SM="${SM:-$(command -v skills-manager-cli || echo "$HOME/.skills-manager/bin/skills-manager-cli.exe")}"
[ -x "$SM" ] && "$SM" projects undeploy --agent codex "$REPO" agent-collab
```

`worktree remove` 遇到脏工作树会拒绝。先确认那些改动是要保留还是要丢弃——**不要用 `--force` 跳过判断**。冲突停下时同样不要 `merge --abort` 之后假装没发生，把两边内容贴出来交人工。
