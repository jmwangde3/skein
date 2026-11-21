#!/usr/bin/env bash
# 生成工作区机械地图：只读文件系统与 git 元数据，不读源码、不做判断。
#
#   bash map.sh --workspace <目录> [--kb <知识库目录>] [--force]
#
# 由 init.sh 在建库时调用；也可以单独跑来刷新地图。
# 输出固定写到 <知识库>/facts/workspace-map.md。
#
# 性能注意：Windows Git Bash 每次 fork 约 50–100 ms，所以这里尽量只用 bash 内建，
# 不按目录调用 find/wc/sed/tr。实测这样能从 12 秒降到 1 秒级。

set -euo pipefail
shopt -s nullglob

WORKSPACE=""
KB=""
FORCE=0
MIN_ENTRIES=3

usage() {
  cat <<'EOF'
用法：map.sh --workspace <目录> [--kb <知识库目录>] [--force]

  --workspace <目录>   工作区根；默认当前目录
  --kb <目录>          知识库目录；不给就从工作区根 AGENTS.local.md 的 kb 键读
  --force              有效条目少于 3 个也生成
  -h, --help           显示本帮助

只统计顶层条目，不含隐藏项。不算递归体积——一个 40 MB 的目录量一次要 20 秒以上。
EOF
}

gap() { printf '[HANDOFF_GAP] %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
wp() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workspace|--project) [ "$#" -ge 2 ] || gap "缺参数值：$1"; WORKSPACE="$2"; shift 2 ;;
    --kb)                  [ "$#" -ge 2 ] || gap "缺参数值：$1"; KB="$2";        shift 2 ;;
    --force)               FORCE=1; shift ;;
    -h|--help)             usage; exit 0 ;;
    *)                     gap "未知参数：$1（用 -h 看用法）" ;;
  esac
done

[ -n "$WORKSPACE" ] || WORKSPACE="$(pwd)"
[ -d "$WORKSPACE" ] || gap "目录不存在：$WORKSPACE"
SCOPE="$(cd "$WORKSPACE" && pwd -P)"

# 知识库路径只能从路由读，不猜
if [ -z "$KB" ]; then
  ROUTE="$SCOPE/AGENTS.local.md"
  [ -f "$ROUTE" ] || gap "缺 $ROUTE，先建库"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      kb:*) KB="${line#kb:}"; KB="${KB#"${KB%%[![:space:]]*}"}"; KB="${KB%"${KB##*[![:space:]]}"}"; break ;;
    esac
  done < "$ROUTE"
  [ -n "$KB" ] || gap "路由里没有 kb 键"
fi
[ -d "$KB" ] || gap "知识库目录不存在：$KB"

skip_name() {
  case "$1" in
    AGENTS.local.md|node_modules|.venv|venv|dist|build|target) return 0 ;;
    *) return 1 ;;
  esac
}

# 先数一遍有效条目（glob 天然不含隐藏项），决定要不要生成
count=0
for p in "$SCOPE"/*; do
  base="${p##*/}"
  skip_name "$base" && continue
  if [ -d "$p" ] || [ -f "$p" ]; then count=$((count + 1)); fi
done

if [ "$count" -lt "$MIN_ENTRIES" ] && [ "$FORCE" -ne 1 ]; then
  say "顶层有效条目只有 $count 个（少于 $MIN_ENTRIES），跳过地图。需要就加 --force"
  exit 0
fi

OUT="$KB/facts/workspace-map.md"
TMP="$KB/facts/.workspace-map.$$"
mkdir -p "$KB/facts"
trap 'rm -f "$TMP"' EXIT

{
  printf '# 工作区机械地图\n\n'
  printf '> 生成时间：%s\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '> 扫描范围：%s 的顶层条目（不含隐藏项）\n' "$(wp "$SCOPE")"
  printf '> 性质：机械快照，不是当前状态的权威来源。动手前先核对目标目录与 Git HEAD。\n'
  printf '> 本文件由 `scripts/map.sh` 生成，不要手工编辑；要补说明写 `facts/workspace-notes.md`。\n\n'
  printf '| 条目 | 类型 | 最后提交 | 顶层条目数 | 备注 |\n'
  printf '|---|---|---|---:|---|\n'
} > "$TMP"

for p in "$SCOPE"/*; do
  base="${p##*/}"
  skip_name "$base" && continue
  [ -e "$p" ] || continue

  kind="目录"; last="-"; subs="-"; note="无"

  if [ -d "$p" ]; then
    subs=0
    for _c in "$p"/*; do subs=$((subs + 1)); done

    # 只有「$p/.git 存在，且 toplevel 就是 $p 自己」才算独立仓。
    # 不能只看 rev-parse --is-inside-work-tree：工作区本身是仓时子目录也会返回 true。
    if [ -e "$p/.git" ]; then
      top="$(git -C "$p" rev-parse --show-toplevel 2>/dev/null || true)"
      if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$(cd "$p" && pwd -P)" ]; then
        kind="git 仓"
        last="$(git -C "$p" log -1 --format=%cs 2>/dev/null || true)"
        [ -n "$last" ] || last="无提交"
      else
        kind="目录（.git 异常）"
      fi
    fi

    # 备注：先 package.json 的 name@version（同名副本靠它区分），再 README 首个正文行
    if [ -f "$p/package.json" ]; then
      pj="$(<"$p/package.json")"
      if [[ $pj =~ \"name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
        pkg="${BASH_REMATCH[1]}"
        ver=""
        [[ $pj =~ \"version\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && ver="${BASH_REMATCH[1]}"
        note="package.json: ${pkg}${ver:+@$ver}"
      fi
    fi
    if [ "$note" = "无" ] && [ -f "$p/README.md" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue
        case "$line" in
          \#*) while [[ $line == \#* ]]; do line="${line#\#}"; done
               line="${line#"${line%%[![:space:]]*}"}"
               [ -z "$line" ] && continue ;;
          \!*|\[*|\<*) continue ;;
        esac
        note="README: ${line:0:40}"; break
      done < "$p/README.md"
    fi
  else
    kind="文件"
  fi

  # 表格转义：竖线必须转义，反引号去掉以免破坏行内代码
  name_md="${base//\`/}"; name_md="${name_md//|/\\|}"
  note_md="${note//|/\\|}"
  printf '| `%s` | %s | %s | %s | %s |\n' "$name_md" "$kind" "$last" "$subs" "$note_md" >> "$TMP"
done

mv -f "$TMP" "$OUT"
say "地图已写：$OUT（$count 项）"
