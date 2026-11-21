# 接入一个工作区并建库

这是**唯一**的建库入口。`install.sh` 只负责把技能复制到客户端，不碰任何项目目录。

一次接入产出的东西：

- 工作区根的 `AGENTS.local.md`（本机路由，不入库）
- `<数据家>/<工作区名>/{store,checkpoints,kb,backups,worktrees}`
- `kb` 独立 git 仓 + 首版 `INDEX.md` / `current.md` + 一次提交
- 可选：任务库 `bd init`

## 0. 先确认作用域

**作用域 = 一个目录，可以从上往下包含多个 git 仓。** 库是按作用域建的，不是按仓建的。

```bash
SCOPE="${SCOPE:-$(pwd -P)}"
[ -d "$SCOPE" ] || { echo "[HANDOFF_GAP] 目录不存在：$SCOPE"; exit 1; }
NAME="$(basename "$SCOPE")"

# 已有路由就用已有的，不重建
if [ -f "$SCOPE/AGENTS.local.md" ]; then
  echo "已存在：$SCOPE/AGENTS.local.md（跳过创建，只核对）"
fi

# 子目录里如果还有别的 AGENTS.local.md，会遮住这一份，得先处理
find "$SCOPE" -mindepth 2 -name AGENTS.local.md -not -path "*/.git/*" 2>/dev/null
```

最后那条命令有输出就**先停下**，把清单给用户：问他是"并到工作区库"还是"留作独立库"。不要自己删，也不要自己改。

## 1. 定数据家

默认 `~/skein-data`；用户指定了就用他指定的，**必须在代码仓之外**。

```bash
DATA="${DATA:-$HOME/skein-data}"
D="$DATA/$NAME"
mkdir -p "$DATA"
DATA="$(cd "$DATA" && pwd -P)"
D="$DATA/$NAME"
```

两条硬约束，命中就停：

```bash
# 1) 数据家不许落在任何 git 工作树里
if git -C "$DATA" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[HANDOFF_GAP] 数据家 $DATA 在 git 仓里，私有库会被提交"; exit 1
fi
# 2) 数据目录已被占用但工作区没有路由 —— 可能是另一个同名工作区
if [ -f "$D/kb/INDEX.md" ] && [ ! -f "$SCOPE/AGENTS.local.md" ]; then
  echo "[HANDOFF_GAP] $D 已有知识库但没有路由，先确认是不是同一个工作区"; exit 1
fi
```

## 2. 建目录

```bash
mkdir -p "$D"/{store,checkpoints,backups,worktrees}
mkdir -p "$D/kb"/{facts,decisions,runbooks,journal,proposals,archive}
```

## 3. 写 `AGENTS.local.md`

已存在就**不动**，只核对五个键齐不齐。不存在才写。

`pwd -P` 在 Windows 下给的是 `/c/...`，`bd`、`es`、`qmd` 是原生程序，读不了这种路径。**写进文件前必须转成 `C:/...`**：

```bash
wp() { command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || printf '%s' "$1"; }
```

```bash
LOCAL="$SCOPE/AGENTS.local.md"
if [ ! -f "$LOCAL" ]; then
  cat > "$LOCAL" <<EOF
# 本机协作路由 · $NAME

> 这个文件含本机绝对路径，不进版本控制，永不提交。
> 换电脑、换目录、换工作区时，只改这里。

scope: $(wp "$SCOPE")
store: $(wp "$D")/store
checkpoints: $(wp "$D")/checkpoints
kb: $(wp "$D")/kb
backups: $(wp "$D")/backups
worktree_root: $(wp "$D")/worktrees
EOF
fi

for k in store checkpoints kb worktree_root; do
  grep -q "^$k:" "$LOCAL" || echo "[HANDOFF_GAP] AGENTS.local.md 缺键：$k"
done
# scope 是后加的；老文件里叫 project，两者认一个就行
grep -qE '^(scope|project):' "$LOCAL" || echo "[HANDOFF_GAP] AGENTS.local.md 缺键：scope"
```

写完之后打开确认一眼：五个键的值都应该是 `C:/...` 或 `/home/...` 这种绝对路径，不能是 `/c/...`。

## 4. 只在必要时写忽略

作用域根**本身是某个 git 仓的根**时（判据：`$SCOPE/.git` 存在），`AGENTS.local.md` 会被看到，必须排除。作用域只是个父目录（不在任何仓里）就不用管——它天然进不了提交。

别用 `git rev-parse --show-toplevel` 比字符串：Git for Windows 返回 `C:/...`，而 `pwd -P` 给的是 `/c/...`，比不出相等。

```bash
if [ -e "$SCOPE/.git" ]; then
  # 已被跟踪的，忽略规则救不回来，先停下让人处理
  git -C "$SCOPE" ls-files --error-unmatch AGENTS.local.md >/dev/null 2>&1 \
    && { echo "[HANDOFF_GAP] AGENTS.local.md 已被跟踪，先 git rm --cached"; exit 1; }
  EX="$(git -C "$SCOPE" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null \
        || git -C "$SCOPE" rev-parse --git-path info/exclude)"
  mkdir -p "$(dirname "$EX")"
  grep -qxF '/AGENTS.local.md' "$EX" 2>/dev/null || echo '/AGENTS.local.md' >> "$EX"
fi
```

## 5. 建知识库

```bash
[ -e "$D/kb/.git" ] || git -C "$D/kb" init -q
[ -z "$(git -C "$D/kb" remote 2>/dev/null)" ] \
  || { echo "[HANDOFF_GAP] kb 已有远程，私有库不该有远程"; exit 1; }
```

首版 `INDEX.md` 必须有的三块：一句话说清管什么不管什么、分类表、常查表。控制在 1000 tokens 内——超了就是导航变内容。

```markdown
# <工作区名> · 知识库索引

> 本文件是入口，不是内容。读它只为了知道该去读哪个文件。

## 这个库管什么

- 管：<这个工作区长期有效的事实、决策、操作手册>
- 不管：任务状态（在 Beads）、代码本身（在各自仓库）、一次性过程记录（进 `journal/`）

## 分类

| 目录 | 放什么 | 什么时候看 |
|---|---|---|
| `facts/` | 环境、版本、路径约定等硬事实 | 动手前确认前提 |
| `decisions/` | 为什么这么定，否过什么 | 想改方案时 |
| `runbooks/` | 可照抄的操作步骤 | 要重复做一件事 |
| `journal/` | 按月流水 | 复盘 |
| `proposals/` | 非写者的改动建议 | 合并前 |
| `archive/` | 旧方案、已废弃 | 查历史 |

## 常查

| 想知道 | 看哪 |
|---|---|
| <问题> | `<文件>` |
```

`current.md` 只写：当前阶段、在做什么、下一步。**不复制任务状态**，写一句「任务状态看 `bd -C "$D/store" list`」就够。

把上面两段写成文件（`INDEX.md` 和 `current.md` 都在 `$D/kb/` 下，已存在就别覆盖），然后提交：

```bash
git -C "$D/kb" -c core.autocrlf=false add -A
git -C "$D/kb" -c core.autocrlf=false -c user.name=skein -c user.email=skein@local \
  commit -q -m "kb: 初始化" || true
```

## 6. 任务库（可选）

装了 `bd` 才做。**必须在目录里跑**，`-C` 只对已有库有效。

```bash
if command -v bd >/dev/null 2>&1 && [ ! -d "$D/store/.beads" ]; then
  ( cd "$D/store" && bd init --prefix sk --non-interactive --stealth --skip-agents >/dev/null 2>&1 ) \
    && echo "任务库已建（前缀 sk）" || echo "任务库没建成，可稍后手动补"
fi
```

## 7. 验收

| 项 | 命令 | 期望 |
|---|---|---|
| 路由 | `cat <SCOPE>/AGENTS.local.md` | 五个键都有值 |
| 作用域唯一 | `find <SCOPE> -mindepth 2 -name AGENTS.local.md` | 无输出 |
| 忽略 | 作用域是仓根时 `git check-ignore -v AGENTS.local.md` | 有一行输出 |
| 库独立 | `git -C <KB> remote -v` | 无输出 |
| 库已提交 | `git -C <KB> log --oneline` | 至少一条 |
| 任务库 | `bd -C <STORE> list` | 不报错 |

## 常见错误

- **给每个 git 仓都建一个库。** 库是按工作区建的；子仓共享同一份，任务标题带 `[子仓名]` 区分
- **在子目录又放一份 `AGENTS.local.md`。** 它会遮住工作区那份，技能向上找时就停了
- **数据家放在仓里。** 会被提交、可能被推送
- **让安装脚本顺手建库。** 脚本只复制技能，建库只走这里
