#!/usr/bin/env bash
# Skein 建库：给一个工作区建 store / checkpoints / kb / backups / worktrees
#
# 由 project-memory 技能调用，也可以直接手动跑：
#   bash <技能目录>/project-memory/scripts/init.sh --workspace <目录> [--data <数据家>]
#
# 只建库，不装技能。可重复执行：已有目录、已有路由、已有知识库都不会被覆盖。

set -euo pipefail

WORKSPACE=""
DATA_HOME="${SKEIN_DATA_HOME:-}"
PREFIX="sk"

usage() {
  cat <<'EOF'
用法：init.sh [选项]

  --workspace <目录>   工作区根，默认当前目录
  --data <目录>        数据家，默认 ~/skein-data（也可用环境变量 SKEIN_DATA_HOME）
  --prefix <前缀>      任务库前缀，默认 sk
  -h, --help           显示本帮助

只建库，不装技能。可重复执行，已有内容不会被覆盖。
EOF
}

die() { printf '%s\n' "$*" >&2; exit 2; }
gap() { printf '[HANDOFF_GAP] %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workspace|--project) [ "$#" -ge 2 ] || die "缺参数值：$1"; WORKSPACE="$2"; shift 2 ;;
    --data)                [ "$#" -ge 2 ] || die "缺参数值：$1"; DATA_HOME="$2"; shift 2 ;;
    --prefix)              [ "$#" -ge 2 ] || die "缺参数值：$1"; PREFIX="$2";   shift 2 ;;
    -h|--help)             usage; exit 0 ;;
    *)                     die "未知参数：$1（用 -h 看用法）" ;;
  esac
done

# pwd -P 在 Windows 下给 /c/...，bd / es / qmd 是原生程序读不了；写进文件前转换
wp() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

## 0. 作用域
[ -n "$WORKSPACE" ] || WORKSPACE="$(pwd)"
[ -d "$WORKSPACE" ] || gap "目录不存在：$WORKSPACE"
SCOPE="$(cd "$WORKSPACE" && pwd -P)"
NAME="$(basename "$SCOPE")"
say "作用域：$(wp "$SCOPE")"

# 子目录里的路由会遮住工作区这份，先列出来
NESTED=""
while IFS= read -r -d '' f; do NESTED="${NESTED}${f}"$'\n'; done < <(
  find "$SCOPE" -mindepth 2 \
    \( -name .git -o -name node_modules -o -name .venv -o -name venv \
       -o -name dist -o -name build -o -name target \) -prune -o \
    -name AGENTS.local.md -type f -print0 2>/dev/null || true
)
if [ -n "$NESTED" ]; then
  printf '%s\n' "子目录里还有这些路由文件，它们会遮住工作区这一份：" >&2
  printf '%s' "$NESTED" | sed 's/^/  /' >&2
  gap "先和用户确认：这些子项目是并进来，还是留作独立库。本脚本不会动它们"
fi

## 1. 数据家
[ -n "$DATA_HOME" ] || DATA_HOME="$HOME/skein-data"
mkdir -p "$DATA_HOME" 2>/dev/null || gap "建不了数据家：$DATA_HOME"
DATA_HOME="$(cd "$DATA_HOME" && pwd -P)"
D="$DATA_HOME/$NAME"

if git -C "$DATA_HOME" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  gap "数据家 $(wp "$DATA_HOME") 在 git 仓里，私有库会被提交"
fi

MARKER="$D/.skein-scope"
if [ -f "$MARKER" ]; then
  OWNER="$(head -n 1 "$MARKER" | tr -d '\r')"
  if [ "$OWNER" != "$(wp "$SCOPE")" ] && [ "$OWNER" != "$SCOPE" ]; then
    gap "$(wp "$D") 属于 $OWNER，不是 $(wp "$SCOPE")。换一个 --data"
  fi
elif [ -d "$D" ] && [ -n "$(find "$D" -mindepth 1 -print -quit 2>/dev/null)" ]; then
  gap "$(wp "$D") 已有内容但没有归属标记，先确认它是不是别的同名工作区"
fi

## 2. 目录与归属标记
mkdir -p "$D/store" "$D/checkpoints" "$D/backups" "$D/worktrees"
mkdir -p "$D/kb/facts" "$D/kb/decisions" "$D/kb/runbooks" \
         "$D/kb/journal" "$D/kb/proposals" "$D/kb/archive"
[ -f "$MARKER" ] || printf '%s\n' "$(wp "$SCOPE")" > "$MARKER"
say "数据目录：$(wp "$D")"

## 3. 本机路由
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
  say "已写路由：$(wp "$LOCAL")"
else
  say "沿用已有路由：$(wp "$LOCAL")"
fi

for k in store checkpoints kb worktree_root; do
  grep -q "^$k:" "$LOCAL" || gap "$(wp "$LOCAL") 缺键：$k"
done
grep -qE '^(scope|project):' "$LOCAL" || gap "$(wp "$LOCAL") 缺键：scope"

## 4. 只在必要时写忽略
if [ -e "$SCOPE/.git" ]; then
  if git -C "$SCOPE" ls-files --error-unmatch AGENTS.local.md >/dev/null 2>&1; then
    gap "AGENTS.local.md 已被 git 跟踪，忽略规则救不回来。先 git rm --cached AGENTS.local.md 再重跑"
  fi
  EX="$(git -C "$SCOPE" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null \
        || git -C "$SCOPE" rev-parse --git-path info/exclude)"
  case "$EX" in
    /*|[A-Za-z]:/*) ;;
    *) EX="$SCOPE/$EX" ;;
  esac
  mkdir -p "$(dirname "$EX")"
  grep -qxF '/AGENTS.local.md' "$EX" 2>/dev/null || echo '/AGENTS.local.md' >> "$EX"
  say "已加入忽略：$(wp "$EX")"
fi

## 5. 知识库
KB="$D/kb"
[ -e "$KB/.git" ] || git -C "$KB" init -q
if [ -n "$(git -C "$KB" remote 2>/dev/null || true)" ]; then
  gap "kb 已配置远程：私有库不该有远程。先人工核对 $(wp "$KB")"
fi

NEW_KB=0
[ -f "$KB/INDEX.md" ] || NEW_KB=1

if [ ! -f "$KB/INDEX.md" ]; then
  cat > "$KB/INDEX.md" <<EOF
# $NAME · 知识库索引

> 本文件是入口，不是内容。读它只为了知道该去读哪个文件。

## 这个库管什么

- 管：这个工作区长期有效的事实、决策、操作手册
- 不管：任务状态（在任务库）、代码本身（在各自仓库）、一次性过程记录（进 \`journal/\`）

## 分类

| 目录 | 放什么 | 什么时候看 |
|---|---|---|
| \`facts/\` | 环境、版本、路径约定等硬事实 | 动手前确认前提 |
| \`decisions/\` | 为什么这么定，否过什么 | 想改方案时 |
| \`runbooks/\` | 可照抄的操作步骤 | 要重复做一件事 |
| \`journal/\` | 按月流水 | 复盘 |
| \`proposals/\` | 非写者的改动建议 | 合并前 |
| \`archive/\` | 旧方案、已废弃 | 查历史 |

## 常查

| 想知道 | 看哪 |
|---|---|
| 当前在做什么 | \`current.md\` |
EOF
fi

if [ ! -f "$KB/current.md" ]; then
  cat > "$KB/current.md" <<EOF
# $NAME · 当前

- 阶段：刚建库
- 在做什么：无
- 下一步：无

任务状态看 \`bd -C "$(wp "$D")/store" list\`，这里不复制。
EOF
fi

# 顺手生成工作区地图（机械快照，给新 agent 定位用）。失败不影响建库。
MAP_SH="$(cd "$(dirname "$0")" && pwd)/map.sh"
if [ -f "$MAP_SH" ]; then
  bash "$MAP_SH" --workspace "$SCOPE" --kb "$KB" || say "地图没生成，可稍后单独跑：bash \"$(wp "$MAP_SH")\" --workspace \"$(wp "$SCOPE")\""
fi

git -C "$KB" -c core.autocrlf=false add -A
if ! git -C "$KB" diff --cached --quiet; then
  if [ "$NEW_KB" -eq 1 ]; then MSG="kb: 初始化"; else MSG="kb: 刷新地图与索引"; fi
  git -C "$KB" -c core.autocrlf=false -c user.name=skein -c user.email=skein@local \
    commit -q -m "$MSG"
  say "知识库已提交（$MSG）"
fi

## 6. 任务库（可选）
if command -v bd >/dev/null 2>&1; then
  if [ ! -d "$D/store/.beads" ]; then
    if ( cd "$D/store" && bd init --prefix "$PREFIX" --non-interactive --stealth --skip-agents >/dev/null 2>&1 ); then
      say "任务库已建（前缀 $PREFIX）"
    else
      say "任务库没建成，可稍后手动补：( cd \"$(wp "$D/store")\" && bd init --prefix $PREFIX )"
    fi
  fi
else
  say "没装 bd，任务库留空。装好后在 $(wp "$D/store") 里跑 bd init --prefix $PREFIX"
fi

## 7. 收尾
say ""
say "完成。自检："
printf '  %-10s %s\n' "路由" "$(wp "$LOCAL")"
printf '  %-10s %s\n' "归属标记" "$(wp "$MARKER")"
printf '  %-10s %s\n' "知识库" "$(wp "$KB")"
printf '  %-10s %s\n' "任务库" "$(wp "$D/store")"
say ""
say "下一步：让 AI 读一遍 AGENTS.local.md，确认 store 和 kb 能说对。"
