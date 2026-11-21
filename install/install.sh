#!/usr/bin/env bash
# Skein 安装脚本（macOS / Linux / Windows Git Bash）
# 用法：bash install/install.sh [--client all|claude|codex|workbuddy|custom] [--dir <技能目录>]
#                               [--project <项目路径>] [--data <数据家>] [--prefix sk] [--force]
set -euo pipefail

CLIENT="all"
CUSTOM_DIR=""
PROJECT=""
DATA=""
PREFIX="sk"
FORCE=0

usage() {
  cat <<'EOF'
Skein 安装脚本

  --client <名字>   装到哪些客户端：all（默认）/ claude / codex / workbuddy / custom
  --dir <路径>      --client custom 时，技能装到这个目录
  --project <路径>  顺便给这个项目做部署（建数据目录、生成 AGENTS.local.md、初始化知识库）
  --data <路径>     数据家目录，默认 ~/skein-data
  --prefix <字母>   任务库前缀，默认 sk
  --force           已存在的技能目录也覆盖
  -h, --help        显示这段说明

例：
  bash install/install.sh --client all
  bash install/install.sh --client claude --project "D:/work/我的项目" --data "D:/skein-data"
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --client)  CLIENT="${2:-}"; shift 2 ;;
    --dir)     CUSTOM_DIR="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --data)    DATA="${2:-}"; shift 2 ;;
    --prefix)  PREFIX="${2:-}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="task-checkpoint agent-handoff project-memory agent-collab"

# Git Bash 下把 /c/Users/x 转成 C:/Users/x，写进 AGENTS.local.md 才能被 Windows 程序读
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

install_to() {
  local dest="$1" s
  mkdir -p "$dest"
  for s in $SKILLS; do
    if [ -e "$dest/$s" ] && [ "$FORCE" -ne 1 ]; then
      echo "  跳过（已存在）：$dest/$s"
      continue
    fi
    rm -rf "$dest/$s"
    cp -R "$REPO/skills/$s" "$dest/$s"
    echo "  已装：$dest/$s"
  done
}

echo "== 1/2 安装技能 =="
case "$CLIENT" in
  claude)    install_to "$HOME/.claude/skills" ;;
  codex)     install_to "$HOME/.codex/skills" ;;
  workbuddy) install_to "$HOME/.workbuddy/skills" ;;
  all)
    install_to "$HOME/.claude/skills"
    install_to "$HOME/.codex/skills"
    install_to "$HOME/.workbuddy/skills"
    ;;
  custom)
    [ -n "$CUSTOM_DIR" ] || { echo "--client custom 必须同时给 --dir" >&2; exit 2; }
    install_to "$CUSTOM_DIR"
    ;;
  *) echo "不认识的客户端：$CLIENT" >&2; exit 2 ;;
esac

if [ -z "$PROJECT" ]; then
  echo
  echo "技能装好了。要做项目部署，再加 --project <项目路径> 重跑。"
  exit 0
fi

echo
echo "== 2/2 部署到项目 =="
[ -d "$PROJECT" ] || { echo "项目目录不存在：$PROJECT" >&2; exit 2; }
PROJ="$(cd "$PROJECT" && pwd)"
NAME="$(basename "$PROJ")"
ROOT_REAL="${DATA:-$HOME/skein-data}"
mkdir -p "$ROOT_REAL"
ROOT_REAL="$(cd "$ROOT_REAL" && pwd)"
D="$ROOT_REAL/$NAME"

mkdir -p "$D/store" "$D/checkpoints" "$D/backups"
mkdir -p "$D/kb/facts" "$D/kb/decisions" "$D/kb/runbooks" \
         "$D/kb/journal" "$D/kb/proposals" "$D/kb/archive"
echo "  数据目录：$(winpath "$D")"

LOCAL="$PROJ/AGENTS.local.md"
if [ -f "$LOCAL" ]; then
  echo "  AGENTS.local.md 已存在，保留不动"
else
  sed -e "s|{{PROJECT}}|$NAME|g" \
      -e "s|{{DATA}}|$(winpath "$D")|g" \
      -e "s|{{WORKTREE_ROOT}}|$(winpath "$ROOT_REAL")|g" \
      "$REPO/templates/AGENTS.local.md" > "$LOCAL"
  echo "  已生成：AGENTS.local.md"
fi

if [ -d "$PROJ/.git" ]; then
  EX="$PROJ/.git/info/exclude"
  grep -qx '/AGENTS.local.md' "$EX" 2>/dev/null || echo '/AGENTS.local.md' >> "$EX"
  echo "  已加入 .git/info/exclude"
else
  echo "  提示：这个目录还不是 git 仓，AGENTS.local.md 暂时无处排除；git init 后重跑本脚本即可"
fi

# 知识库：独立仓、无远程
if [ ! -d "$D/kb/.git" ]; then
  git -C "$D/kb" init -q
  echo "  知识库已初始化（独立仓）"
fi
[ -f "$D/kb/INDEX.md" ]   || sed -e "s|{{PROJECT}}|$NAME|g" "$REPO/templates/kb-INDEX.md" > "$D/kb/INDEX.md"
[ -f "$D/kb/current.md" ] || cp "$REPO/templates/kb-current.md" "$D/kb/current.md"
if [ -z "$(git -C "$D/kb" log --oneline 2>/dev/null)" ]; then
  git -C "$D/kb" -c core.autocrlf=false add -A
  git -C "$D/kb" -c core.autocrlf=false -c user.name=skein -c user.email=skein@local commit -q -m "kb: 初始化"
  echo "  知识库已提交"
fi

# 任务库
if [ -d "$D/store/.beads" ]; then
  echo "  任务库已存在，跳过 init"
elif command -v bd >/dev/null 2>&1; then
  ( cd "$D/store" && bd init --prefix "$PREFIX" --non-interactive --stealth --skip-agents >/dev/null 2>&1 )
  echo "  任务库已初始化（前缀 $PREFIX）"
else
  echo "  未找到 bd，任务库留空。装好 Beads 后进入目录再 init："
  echo "    cd \"$(winpath "$D")/store\" && bd init --prefix $PREFIX --non-interactive --stealth --skip-agents"
fi

cat <<EOF

完成。还差三步手工动作：

1. 把 templates/AGENTS.md.pointer.md 里「Skein 协作」那一节贴进 $NAME/AGENTS.md
2. 重启 AI 客户端（多数客户端只在启动时扫描技能目录）
3. 自检：git -C "$(winpath "$D")/kb" remote -v   必须没有任何输出

数据目录结构：
  $(winpath "$D")/{store,checkpoints,kb,backups}
EOF
