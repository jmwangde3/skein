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

# 只放路径，不写规则；规则在 AGENTS.md（a 全局 / b 工作区 / c 项目）。
# a 层改法：改 ~/.workbuddy/agent-memory-snippet.md，再跑 agent-workspace-bridge/sync-agent-memory.ps1 -Update。
EOF
  say "已写路由：$(wp "$LOCAL")"
else
  say "沿用已有路由：$(wp "$LOCAL")"
fi

for k in store checkpoints kb worktree_root; do
  grep -q "^$k:" "$LOCAL" || gap "$(wp "$LOCAL") 缺键：$k"
done
grep -qE '^(scope|project):' "$LOCAL" || gap "$(wp "$LOCAL") 缺键：scope"

## 4. 收尾纪律（写进 b 层 AGENTS.md）
B="$SCOPE/AGENTS.md"
BLOCK_FILE="$(mktemp 2>/dev/null || echo "$SCOPE/.skein-block.$$")"
cat > "$BLOCK_FILE" <<'EOF'
<!-- skein-rules -->
## Skein 收尾纪律

- 长任务在阶段完成、决策推翻旧做法、遇阻，或用户说「先到这 / 新开会话 / 明天继续」时，**主动**写检查点，不等提醒；恢复时先读它。
- 用户说「写 handoff」：先找 `agent-handoff` 技能。找到就加载它、按它的流程写 handoff；没找到就写检查点，回复里报路径。
- 长任务回复末尾报 `检查点：<路径>` 或 `检查点：无（原因）`。
- 路径从 `AGENTS.local.md` 的 `checkpoints` 键读；缺键报 `[HANDOFF_GAP]`。
- 任务状态只在 Beads，检查点不复制状态。
- 做法（模板、rev、写入协议）见 `task-checkpoint` 技能；本块只写时机和不变量。
<!-- /skein-rules -->
EOF
if [ ! -f "$B" ]; then
  printf '# 工作区规则 — %s\n\n' "$NAME" > "$B"
  say "已建 b 层：$(wp "$B")"
fi
if grep -q '<!-- skein-rules -->' "$B"; then
  BLOCK_FILE="$BLOCK_FILE" awk '
    BEGIN { while ((getline line < ENVIRON["BLOCK_FILE"]) > 0) block = block line ORS }
    /<!-- skein-rules -->/ { printf "%s", block; skip = 1; next }
    /<!-- \/skein-rules -->/ { skip = 0; next }
    !skip { print }
  ' "$B" > "$B.skein.$$" && mv -f "$B.skein.$$" "$B"
  say "已更新收尾纪律：$(wp "$B")"
else
  [ -s "$B" ] && [ -n "$(tail -c1 "$B")" ] && echo >> "$B"
  printf '\n' >> "$B"
  cat "$BLOCK_FILE" >> "$B"
  say "已写入收尾纪律：$(wp "$B")（要提交）"
fi
rm -f "$BLOCK_FILE"

## 5. 写忽略（.gitignore 随仓库走，换机也生效）
if [ -e "$SCOPE/.git" ]; then
  if git -C "$SCOPE" ls-files --error-unmatch AGENTS.local.md >/dev/null 2>&1; then
    gap "AGENTS.local.md 已被 git 跟踪，忽略规则救不回来。先 git rm --cached AGENTS.local.md 再重跑"
  fi
  GI="$SCOPE/.gitignore"
  if grep -qxF '/AGENTS.local.md' "$GI" 2>/dev/null; then
    say "已有忽略：$(wp "$GI")"
  else
    [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ] && echo >> "$GI"
    echo '/AGENTS.local.md' >> "$GI"
    say "已写忽略：$(wp "$GI")（这个文件要提交）"
  fi
fi

## 6. 知识库
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

# 项目档案索引：把每个 git 仓列进来，状态先标 TODO。
# 语义建档由 agent 按 references/brief.md 完成，脚本不读源码。
PROJ_DIR="$KB/facts/projects"
IDX="$PROJ_DIR/INDEX.md"
mkdir -p "$PROJ_DIR"

hash8() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi | cut -c1-8
}

skip_dir() {
  case "$1" in
    node_modules|.venv|venv|dist|build|target|.git) return 0 ;;
    *) return 1 ;;
  esac
}

# 收集仓：工作区根自身 + 顶层 + 第二层。路径按行存放，容忍空格。
# 判据是「有 .git（文件或目录）且 toplevel 就是自己」，这样 linked worktree
# （.git 是文件）能识别，父仓里的普通子目录不会被误判。
REPO_LIST=""
add_repo() {
  if [ -z "$REPO_LIST" ]; then REPO_LIST="$1"; else REPO_LIST="$REPO_LIST"$'\n'"$1"; fi
}
is_repo_root() {
  [ -e "$1/.git" ] || return 1
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$1" && pwd -P)" ]
}

# 工作区根本身就是一个项目仓——单项目建库最常见的形态，必须先算进来
if is_repo_root "$SCOPE"; then add_repo "."; fi

# 注意：脚本开头是 set -e，所有条件都得用 if，不能写 [ x ] && continue
for d in "$SCOPE"/*/; do
  [ -d "$d" ] || continue
  if skip_dir "$(basename "${d%/}")"; then continue; fi
  for cand in "$d" "$d"*/; do
    [ -d "$cand" ] || continue
    if skip_dir "$(basename "${cand%/}")"; then continue; fi
    is_repo_root "$cand" || continue
    rel="${cand#"$SCOPE"/}"; rel="${rel%/}"
    case $'\n'"$REPO_LIST"$'\n' in *$'\n'"$rel"$'\n'*) continue ;; esac
    add_repo "$rel"
  done
done

if [ -z "$REPO_LIST" ]; then
  say "工作区里没有 git 仓，不建项目档案索引"
else
  tmp="$IDX.tmp.$$"
  {
    printf '# 项目档案索引\n\n'
    printf '> 每个 git 仓一行。`TODO` = 还没建档；`PARTIAL` = 建了但关键字段没核实。\n'
    printf '> 档案在同目录 `<仓名>.md`。接手时只读**当前涉及的仓**那一份，不要全读。\n'
    printf '> 由 `scripts/init.sh` 生成；状态由建档 agent 更新。\n\n'
    printf '| 仓 | 相对路径 | 档案 | 状态 | 基线 HEAD |\n'
    printf '|---|---|---|---|---|\n'
    n=0
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      if [ "$rel" = "." ]; then base="$(basename "$SCOPE")"; else base="$(basename "$rel")"; fi
      file="$base.md"
      # 同名仓加路径 hash，避免互相覆盖
      dup=0
      while IFS= read -r other; do
        [ -n "$other" ] || continue
        if [ "$other" = "$rel" ]; then continue; fi
        if [ "$other" = "." ]; then obase="$(basename "$SCOPE")"; else obase="$(basename "$other")"; fi
        if [ "$obase" = "$base" ]; then dup=1; break; fi
      done <<EOF
$REPO_LIST
EOF
      if [ "$dup" -eq 1 ]; then file="$base-$(printf '%s' "$rel" | hash8).md"; fi

      st="TODO"; sha="-"
      if [ -f "$PROJ_DIR/$file" ]; then
        st="$(sed -n 's/^- 状态：[[:space:]]*//p' "$PROJ_DIR/$file" | head -1 | tr -d '\r')"
        [ -n "$st" ] || st="PARTIAL"
        sha="$(sed -n 's/^- 基线：[[:space:]]*//p' "$PROJ_DIR/$file" | head -1 | tr -d '\r' | cut -d' ' -f1)"
        [ -n "$sha" ] || sha="-"
      fi
      printf '| `%s` | `%s` | `%s` | %s | %s |\n' "$base" "$rel" "$file" "$st" "$sha"
      n=$((n + 1))
    done <<EOF
$REPO_LIST
EOF
    printf '\n共 %d 个仓。未建档的项：`grep "| TODO |" INDEX.md`\n' "$n"
  } > "$tmp"
  mv -f "$tmp" "$IDX"
  say "项目档案索引已写：$n 个仓（$(wp "$IDX")）"
fi

git -C "$KB" -c core.autocrlf=false add -A
if ! git -C "$KB" diff --cached --quiet; then
  if [ "$NEW_KB" -eq 1 ]; then MSG="kb: 初始化"; else MSG="kb: 刷新地图与索引"; fi
  git -C "$KB" -c core.autocrlf=false -c user.name=skein -c user.email=skein@local \
    commit -q -m "$MSG"
  say "知识库已提交（$MSG）"
fi

## 7. 任务库（可选）
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

## 8. 收尾
say ""
say "完成。自检："
printf '  %-10s %s\n' "路由" "$(wp "$LOCAL")"
printf '  %-10s %s\n' "归属标记" "$(wp "$MARKER")"
printf '  %-10s %s\n' "知识库" "$(wp "$KB")"
printf '  %-10s %s\n' "任务库" "$(wp "$D/store")"
say ""
say "下一步：让 AI 读一遍 AGENTS.local.md，确认 store 和 kb 能说对。"
