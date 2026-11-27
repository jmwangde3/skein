#!/usr/bin/env bash
# Skein v2.0.5 安装脚本（macOS / Linux / Windows Git Bash）
# 1. 安装 bin/skein-cli 到 ~/.local/bin/skein-cli
# 2. --client all 时仅安装到本机已存在配置目录的客户端，不污染未安装客户端目录
# 3. 支持 --cli-only（使用 skills-manager 管技能时只装 CLI）
set -euo pipefail

CLIENT="all"
CUSTOM_DIR=""
PROJECT=""
WITH_ALL_SKILLS=0
CLI_ONLY=0
FORCE=0

GLOBAL_SKILL="task-checkpoint"
DEFAULT_PROJECT_SKILLS="agent-handoff"
ON_DEMAND_SKILLS="skein-init kb-retrieval agent-collab"

usage() {
  cat <<'EOF'
Skein v2.0.5 安装脚本（装技能 + skein-cli，不自动建库）

  --client <名字>   all（默认，仅装本机已存在的客户端）/ claude / codex / workbuddy / antigravity / qoder-cn / custom
  --dir <路径>      --client custom 时装到这个目录
  --project <路径>  给指定工作区安装项目级常驻技能（默认只装 agent-handoff）
  --all-skills      配合 --project 时，额外复制按需技能（skein-init/kb-retrieval/agent-collab）
  --cli-only        仅安装 skein-cli，不触碰任何技能目录（适合 skills-manager 用户）
  --force           覆盖已存在的普通目录（拒绝拆除 skills-manager 符号链接）
  -h, --help        显示帮助
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --client)     CLIENT="${2:-}"; shift 2 ;;
    --dir)        CUSTOM_DIR="${2:-}"; shift 2 ;;
    --project)    PROJECT="${2:-}"; shift 2 ;;
    --all-skills) WITH_ALL_SKILLS=1; shift ;;
    --cli-only)   CLI_ONLY=1; shift ;;
    --force)      FORCE=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_one() {
  local dest="$1" s="$2" tmp
  if [ "$(cd "$dest" 2>/dev/null && pwd -P)" = "$REPO/skills" ]; then
    echo "拒绝：安装目标就是源目录 $dest/$s" >&2; exit 2
  fi
  if [ -L "$dest/$s" ]; then
    if [ "$FORCE" -eq 1 ]; then
      echo "拒绝用 --force 拆除符号链接：$dest/$s（请通过 skills-manager 管理）" >&2; exit 2
    fi
    echo "  跳过（符号链接）：$dest/$s"
    return 0
  fi
  if [ -e "$dest/$s" ] && [ "$FORCE" -ne 1 ]; then
    echo "  跳过（已存在）：$dest/$s"
    return 0
  fi
  mkdir -p "$dest"
  tmp="$dest/.$s.new.$$"
  rm -rf "$tmp"
  cp -R "$REPO/skills/$s" "$tmp"
  rm -rf "$dest/$s"
  mv "$tmp" "$dest/$s"
  echo "  已装：$dest/$s"
}

install_if_client_exists() {
  local base="$1" s="$2"
  if [ -d "$base" ]; then
    install_one "$base/skills" "$s"
  else
    echo "  跳过（未检测到客户端目录）：$base"
  fi
}

install_cli() {
  local bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  cp "$REPO/bin/skein-cli" "$bindir/skein-cli"
  chmod +x "$bindir/skein-cli"
  echo "  已装 CLI：$bindir/skein-cli"
}

install_project_skills() {
  local proj="$1" dirname="$2" dest ex s list
  dest="$proj/$dirname/skills"
  list="$DEFAULT_PROJECT_SKILLS"
  [ "$WITH_ALL_SKILLS" -eq 1 ] && list="$list $ON_DEMAND_SKILLS"
  for s in $list; do install_one "$dest" "$s"; done
  ex="$(git -C "$proj" rev-parse --git-path info/exclude 2>/dev/null || true)"
  [ -n "$ex" ] || return 0
  case "$ex" in /*|[A-Za-z]:/*) ;; *) ex="$proj/$ex" ;; esac
  mkdir -p "$(dirname "$ex")"
  for s in $list; do
    grep -qxF "/$dirname/skills/$s/" "$ex" 2>/dev/null || echo "/$dirname/skills/$s/" >> "$ex"
  done
}

echo "== 1. 安装 skein-cli =="
install_cli

if [ "$CLI_ONLY" -eq 1 ]; then
  echo "已按 --cli-only 跳过技能复制。确保 ~/.local/bin 在 PATH 中即可。"
  exit 0
fi

echo "== 2. 安装全局常驻技能（$GLOBAL_SKILL）=="
case "$CLIENT" in
  claude)      install_one "$HOME/.claude/skills" "$GLOBAL_SKILL" ;;
  codex)       install_one "$HOME/.codex/skills" "$GLOBAL_SKILL" ;;
  workbuddy)   install_one "$HOME/.workbuddy/skills" "$GLOBAL_SKILL" ;;
  antigravity) install_one "$HOME/.agents/skills" "$GLOBAL_SKILL" ;;
  qoder-cn)    install_one "$HOME/.qoder-cn/skills" "$GLOBAL_SKILL" ;;
  all)
    install_if_client_exists "$HOME/.claude" "$GLOBAL_SKILL"
    install_if_client_exists "$HOME/.codex" "$GLOBAL_SKILL"
    install_if_client_exists "$HOME/.workbuddy" "$GLOBAL_SKILL"
    install_if_client_exists "$HOME/.agents" "$GLOBAL_SKILL"
    install_if_client_exists "$HOME/.qoder-cn" "$GLOBAL_SKILL"
    ;;
  custom)
    [ -n "$CUSTOM_DIR" ] || { echo "--client custom 必须同时给 --dir" >&2; exit 2; }
    install_one "$CUSTOM_DIR" "$GLOBAL_SKILL"
    ;;
  *) echo "未知客户端：$CLIENT" >&2; exit 2 ;;
esac

if [ -n "$PROJECT" ]; then
  [ -d "$PROJECT" ] || { echo "项目目录不存在：$PROJECT" >&2; exit 2; }
  PROJ="$(cd "$PROJECT" && pwd -P)"
  echo "== 3. 安装项目级技能 =="
  case "$CLIENT" in
    all)
      for c in .claude .codex .workbuddy .agents .qoder-cn; do
        [ -d "$HOME/$c" ] && install_project_skills "$PROJ" "$c"
      done
      ;;
    claude)      install_project_skills "$PROJ" ".claude" ;;
    codex)       install_project_skills "$PROJ" ".codex" ;;
    workbuddy)   install_project_skills "$PROJ" ".workbuddy" ;;
    antigravity) install_project_skills "$PROJ" ".agents" ;;
    qoder-cn)    install_project_skills "$PROJ" ".qoder-cn" ;;
    custom)      echo "  --client custom：请自行将项目级技能放到客户端对应目录" ;;
  esac
fi

echo ""
echo "安装完成。确保 ~/.local/bin 在 PATH 中，重启客户端生效。"
