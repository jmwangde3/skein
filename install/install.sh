#!/usr/bin/env bash
# Skein 技能安装脚本（macOS / Linux / Windows Git Bash）
# 只做一件事：把技能复制到客户端能扫到的目录。不建库、不碰数据目录。
# 建库由 agent 读 project-memory/references/init.md 完成。
set -euo pipefail

CLIENT="all"
CUSTOM_DIR=""
PROJECT=""
FORCE=0

GLOBAL_SKILL="task-checkpoint"
PROJECT_SKILLS="agent-handoff project-memory agent-collab"

usage() {
  cat <<'EOF'
Skein 技能安装脚本（只装技能，不建库）

  --client <名字>   all（默认）/ claude / codex / workbuddy / custom
  --dir <路径>      --client custom 时装到这个目录
  --project <路径>  顺便把三个项目级技能放进 <项目>/.<客户端>/skills
  --force           已存在的普通目录也覆盖（不会拆符号链接）
  -h, --help        显示这段说明

装什么：
  全局    task-checkpoint（所有工作区都要用）
  项目级  agent-handoff / project-memory / agent-collab

**没有 --project 就只装全局那一个。** 建库不在这里做。
如果你用 skills-manager 管技能，根本不用跑这个脚本。
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --client)  CLIENT="${2:-}"; shift 2 ;;
    --dir)     CUSTOM_DIR="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_one() {
  local dest="$1" s="$2" tmp
  # 别把安装目标指回源目录，否则 --force 会删掉仓库里的技能本体
  if [ "$(cd "$dest" 2>/dev/null && pwd -P)" = "$REPO/skills" ]; then
    echo "拒绝：安装目标就是技能源目录 $dest/$s" >&2; exit 2
  fi
  # 符号链接是 skills-manager 建的，拆了会破坏单源
  if [ -L "$dest/$s" ]; then
    if [ "$FORCE" -eq 1 ]; then
      echo "拒绝用 --force 拆除符号链接：$dest/$s（由 skills-manager 管理，请在那边卸载）" >&2; exit 2
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
  if ! cp -R "$REPO/skills/$s" "$tmp"; then rm -rf "$tmp"; return 1; fi
  rm -rf "$dest/$s"
  mv "$tmp" "$dest/$s"
  echo "  已装：$dest/$s"
}

install_globals() { install_one "$1" "$GLOBAL_SKILL"; }

install_project_skills() {
  local proj="$1" dirname="$2" dest ex s
  dest="$proj/$dirname/skills"
  for s in $PROJECT_SKILLS; do install_one "$dest" "$s"; done
  ex="$(git -C "$proj" rev-parse --git-path info/exclude 2>/dev/null || true)"
  case "$ex" in
    "" ) return 0 ;;
    /*|[A-Za-z]:/*) ;;
    *) ex="$proj/$ex" ;;
  esac
  mkdir -p "$(dirname "$ex")"
  for s in $PROJECT_SKILLS; do
    grep -qxF "/$dirname/skills/$s/" "$ex" 2>/dev/null || echo "/$dirname/skills/$s/" >> "$ex"
  done
}

echo "== 安装全局技能（只装 $GLOBAL_SKILL）=="
case "$CLIENT" in
  claude)    install_globals "$HOME/.claude/skills" ;;
  codex)     install_globals "$HOME/.codex/skills" ;;
  workbuddy) install_globals "$HOME/.workbuddy/skills" ;;
  all)
    install_globals "$HOME/.claude/skills"
    install_globals "$HOME/.codex/skills"
    install_globals "$HOME/.workbuddy/skills"
    ;;
  custom)
    [ -n "$CUSTOM_DIR" ] || { echo "--client custom 必须同时给 --dir" >&2; exit 2; }
    install_globals "$CUSTOM_DIR"
    ;;
  *) echo "不认识的客户端：$CLIENT" >&2; exit 2 ;;
esac

if [ -n "$PROJECT" ]; then
  [ -d "$PROJECT" ] || { echo "项目目录不存在：$PROJECT" >&2; exit 2; }
  PROJ="$(cd "$PROJECT" && pwd -P)"
  echo
  echo "== 安装项目级技能 =="
  case "$CLIENT" in
    all)       for c in .claude .codex .workbuddy; do install_project_skills "$PROJ" "$c"; done ;;
    claude)    install_project_skills "$PROJ" ".claude" ;;
    codex)     install_project_skills "$PROJ" ".codex" ;;
    workbuddy) install_project_skills "$PROJ" ".workbuddy" ;;
    custom)    echo "  --client custom：项目级三个技能请自行放到客户端能扫到的项目目录" ;;
  esac
fi

cat <<EOF

技能装完了。下一步不是跑脚本，是让 AI 干：

  在这个工作区里对它说「用 project-memory 给这个工作区建库」

它会读 references/init.md：写 AGENTS.local.md、建数据目录、初始化知识库并提交。
建库只做一次，之后所有子项目共用这一套。

重启客户端（多数客户端只在启动时扫描技能目录）。
EOF
