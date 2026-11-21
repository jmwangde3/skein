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

# 全局只有一个：task-checkpoint。另外三个是项目级，只在项目里出现
GLOBAL_SKILL="task-checkpoint"
PROJECT_SKILLS="agent-handoff project-memory agent-collab"

usage() {
  cat <<'EOF'
Skein 安装脚本

  --client <名字>   装到哪些客户端：all（默认）/ claude / codex / workbuddy / custom
  --dir <路径>      --client custom 时，全局技能装到这个目录
  --project <路径>  顺便给这个项目做部署（建数据目录、生成 AGENTS.local.md、初始化知识库）
  --data <路径>     数据家目录，默认 ~/skein-data
  --prefix <字母>   任务库前缀，默认 sk
  --force           已存在的技能目录也覆盖
  -h, --help        显示这段说明

装什么、装到哪：
  全局：只有 task-checkpoint（长任务落盘，所有项目都要用）
  项目：agent-handoff / project-memory / agent-collab，装到 <项目>/.<客户端>/skills

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

# Git Bash 下把 /c/Users/x 转成 C:/Users/x，写进 AGENTS.local.md 才能被 Windows 程序读
winpath() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# sed 替换串里的 \ & | 会被解释，路径里有这些字符时必须转义
esc() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

realpath_dir() { ( cd "$1" && pwd -P ); }

# 先复制到同级临时目录再整体替换，避免复制中断留下半个技能
install_one() {
  local src="$1" dest="$2" s="$3" tmp
  if [ -e "$dest/$s" ] && [ "$FORCE" -ne 1 ]; then
    echo "  跳过（已存在）：$dest/$s"
    return 0
  fi
  mkdir -p "$dest"
  tmp="$dest/.$s.new.$$"
  rm -rf "$tmp"
  cp -R "$src/$s" "$tmp"
  rm -rf "$dest/$s"
  mv "$tmp" "$dest/$s"
  echo "  已装：$dest/$s"
}

install_globals() {
  local dest="$1"
  install_one "$REPO/skills" "$dest" "$GLOBAL_SKILL"
}

# 项目级技能：装到 <项目>/.<客户端>/skills，并把这三条加进本机忽略
install_project_skills() {
  local proj="$1" dirname="$2" dest ex s
  dest="$proj/$dirname/skills"
  for s in $PROJECT_SKILLS; do install_one "$REPO/skills" "$dest" "$s"; done
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

echo "== 1/2 安装全局技能（只有 $GLOBAL_SKILL）=="
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

if [ -z "$PROJECT" ]; then
  echo
  echo "全局技能装好了。要做项目部署，再加 --project <项目路径> 重跑。"
  exit 0
fi

echo
echo "== 2/2 部署到项目 =="
[ -d "$PROJECT" ] || { echo "项目目录不存在：$PROJECT" >&2; exit 2; }
PROJ="$(realpath_dir "$PROJECT")"
NAME="$(basename "$PROJ")"
ROOT_REAL="${DATA:-$HOME/skein-data}"
mkdir -p "$ROOT_REAL"
ROOT_REAL="$(realpath_dir "$ROOT_REAL")"
D="$ROOT_REAL/$NAME"

# 私有数据不许落在代码仓里：一旦被纳管就有推送出去的可能
if TOP="$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null)"; then
  TOP="$(realpath_dir "$TOP")"
  case "$ROOT_REAL/" in
    "$TOP"/*)
      echo "拒绝：数据家 $(winpath "$ROOT_REAL") 在代码仓 $(winpath "$TOP") 里面。私有知识库会被提交，可能被推送出去。" >&2
      echo "换一个仓外的位置，例如 --data \"$(winpath "$HOME/skein-data")\"" >&2
      exit 2
      ;;
  esac
fi

# 同名项目：已有路由指向别处时停下，别让两个项目共用一份数据
LOCAL="$PROJ/AGENTS.local.md"
if [ -f "$LOCAL" ]; then
  OLD_STORE="$(sed -n 's/^store:[[:space:]]*//p' "$LOCAL" | head -n 1 | tr -d '\r')"
  if [ -n "$OLD_STORE" ] && [ "$(winpath "$D")/store" != "$OLD_STORE" ]; then
    echo "拒绝：$LOCAL 里 store 指向 $OLD_STORE，与本次算出的 $(winpath "$D")/store 不一致。" >&2
    echo "两个叫 $NAME 的项目不能共用一份数据。换 --data，或手工改 AGENTS.local.md 后再跑。" >&2
    exit 2
  fi
fi

mkdir -p "$D/store" "$D/checkpoints" "$D/backups"
mkdir -p "$D/kb/facts" "$D/kb/decisions" "$D/kb/runbooks" \
         "$D/kb/journal" "$D/kb/proposals" "$D/kb/archive"
echo "  数据目录：$(winpath "$D")"

if [ -f "$LOCAL" ]; then
  echo "  AGENTS.local.md 已存在，保留不动"
else
  sed -e "s|{{PROJECT}}|$(esc "$NAME")|g" \
      -e "s|{{DATA}}|$(esc "$(winpath "$D")")|g" \
      -e "s|{{WORKTREE_ROOT}}|$(esc "$(winpath "$ROOT_REAL")")|g" \
      "$REPO/templates/AGENTS.local.md" > "$LOCAL"
  echo "  已生成：AGENTS.local.md"
fi

# .git 在 worktree 里是文件不是目录，路径必须问 git（它可能是相对路径）
EX="$(git -C "$PROJ" rev-parse --git-path info/exclude 2>/dev/null || true)"
case "$EX" in
  "" ) EX="" ;;
  /*|[A-Za-z]:/*) ;;
  *) EX="$PROJ/$EX" ;;
esac
if [ -n "$EX" ]; then
  mkdir -p "$(dirname "$EX")"
  grep -qxF '/AGENTS.local.md' "$EX" 2>/dev/null || echo '/AGENTS.local.md' >> "$EX"
  echo "  已加入 .git/info/exclude"
else
  echo "  提示：这个目录还不是 git 仓，AGENTS.local.md 暂时无处排除；git init 后重跑本脚本即可"
fi

# 项目级三个技能：只在项目里出现，并在本机忽略（想提交进仓库就删掉那三行）
case "$CLIENT" in
  all)      for c in .claude .codex .workbuddy; do install_project_skills "$PROJ" "$c"; done ;;
  claude)   install_project_skills "$PROJ" ".claude" ;;
  codex)    install_project_skills "$PROJ" ".codex" ;;
  workbuddy) install_project_skills "$PROJ" ".workbuddy" ;;
  custom)   echo "  --client custom：项目级三个技能请自行放到客户端能扫到的项目目录" ;;
esac

# 知识库：独立仓、无远程。只建空骨架，内容由 project-memory 接手
if [ ! -e "$D/kb/.git" ]; then
  git -C "$D/kb" init -q
  echo "  知识库已初始化（独立仓）"
fi
[ -f "$D/kb/INDEX.md" ]   || sed -e "s|{{PROJECT}}|$(esc "$NAME")|g" "$REPO/templates/kb-INDEX.md" > "$D/kb/INDEX.md"
[ -f "$D/kb/current.md" ] || cp "$REPO/templates/kb-current.md" "$D/kb/current.md"
if [ -z "$(git -C "$D/kb" log --oneline 2>/dev/null)" ]; then
  git -C "$D/kb" -c core.autocrlf=false add -A
  git -C "$D/kb" -c core.autocrlf=false -c user.name=skein -c user.email=skein@local \
    commit -q -m "kb: 初始化骨架" || echo "  知识库提交跳过（无变更）"
  echo "  知识库已提交（空骨架，内容整理交给 project-memory）"
fi

# 任务库
if [ -e "$D/store/.beads" ]; then
  echo "  任务库已存在，跳过 init"
elif command -v bd >/dev/null 2>&1; then
  if ( cd "$D/store" && bd init --prefix "$PREFIX" --non-interactive --stealth --skip-agents >/dev/null 2>&1 ); then
    echo "  任务库已初始化（前缀 $PREFIX）"
  else
    echo "  任务库初始化失败。可手动重试：cd \"$(winpath "$D")/store\" && bd init --prefix $PREFIX --non-interactive --stealth --skip-agents" >&2
  fi
else
  echo "  未找到 bd，任务库留空。装好 Beads 后进入目录再 init："
  echo "    cd \"$(winpath "$D")/store\" && bd init --prefix $PREFIX --non-interactive --stealth --skip-agents"
fi

cat <<EOF

完成。还差三步手工动作：

1. 把 templates/AGENTS.md.pointer.md 里「Skein 协作」那一节贴进 $NAME/AGENTS.md
2. 重启 AI 客户端（多数客户端只在启动时扫描技能目录）
3. 自检：git -C "$(winpath "$D")/kb" remote -v   必须没有任何输出

装了什么：
  全局         $GLOBAL_SKILL
  项目级       $(echo $PROJECT_SKILLS | tr ' ' '/')
  数据目录     $(winpath "$D")/{store,checkpoints,kb,backups}

默认是复制，改本仓库的 skills/ 不会自动生效。想让改动即时生效，
用 skills-manager 部署（它建符号链接），见 README「4.1 档一」。
EOF
