#!/usr/bin/env bash
# check-rules.sh — 只读检查三层规则与路径文件
#
#   bash check-rules.sh [工作区根]
#
# 查七件事：路径文件键齐且没混进规则、b→路径指针与兜底、有没有第二个规则文件、
# 忽略规则在不在 .gitignore、b 里有没有重复长句、a 层是否同步、kb 根有没有规则文件。
# 不改任何文件。有 FAIL 时退出码 1。

set -u

SCOPE="${1:-$PWD}"
SCOPE="$(cd "$SCOPE" 2>/dev/null && pwd -P)" || { echo "[FAIL] 目录不存在：${1:-$PWD}"; exit 1; }

FAIL=0
WARN=0
pass() { printf '  [PASS] %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; WARN=$((WARN + 1)); }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

echo "== 规则自检（三层 + 路径文件）：$SCOPE"

# ---- 路径文件：AGENTS.local.md（不是规则层）----
L="$SCOPE/AGENTS.local.md"
KB=""
if [ ! -f "$L" ]; then
  fail "缺路径文件：AGENTS.local.md（先建库）"
else
  pass "路径文件存在"
  kv() { sed -n "s/^$1:[[:space:]]*//p" "$L" | head -n 1 | tr -d '\r'; }
  KB="$(kv kb)"
  if [ -z "$KB" ]; then
    fail "路径文件缺 kb 键"
  elif [ -d "$KB" ]; then
    pass "kb 路径有效"
  else
    fail "kb 路径不存在：$KB"
  fi
  for k in store checkpoints worktree_root; do
    [ -n "$(kv "$k")" ] || warn "路径文件缺键：$k"
  done
  if grep -qE '^##+ (接手|写回|两层记忆|库的边界|禁止|规则)' "$L"; then
    fail "AGENTS.local.md 里出现规则小节（接手/写回/禁止/规则…）——规则归 AGENTS.md，这里只放路径"
  else
    pass "路径文件没混进规则"
  fi
fi

# ---- b 层：工作区规则 ----
B="$SCOPE/AGENTS.md"
if [ ! -f "$B" ]; then
  warn "无 b 层：AGENTS.md（允许，但项目约束就没有落点）"
else
  pass "b 层存在"
  grep -q "AGENTS.local.md" "$B" && pass "b 指向路径文件" || fail "b 没提 AGENTS.local.md"
  grep -q "HANDOFF_GAP" "$B" && pass "b 有缺失兜底" || fail "b 没写「AGENTS.local.md 缺失或没有 kb 键 → 报 HANDOFF_GAP」"
fi

# ---- 第二个规则文件 ----
for f in RULES.md CONVENTIONS.md NOTES.md GUIDELINES.md STYLE.md MEMORY.md; do
  [ -f "$SCOPE/$f" ] || continue
  size="$(wc -c < "$SCOPE/$f" | tr -d ' ')"
  if [ "$size" -gt 800 ] || ! grep -q "AGENTS.md" "$SCOPE/$f"; then
    fail "疑似第二个规则文件：$f（${size}B）——规则并进 a/b/c，这个文件改成指针"
  else
    warn "指针文件：$f（${size}B）"
  fi
done

# 文件名里带 rule / 规则 的，一律按规则文件处理
while IFS= read -r f; do
  [ -n "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    AGENTS.md|AGENTS.local.md|CLAUDE.md|GEMINI.md|CODEBUDDY.md) continue ;;
  esac
  size="$(wc -c < "$f" | tr -d ' ')"
  fail "疑似规则文件：$base（${size}B）——规则并进 a/b/c，原文进 <kb>/archive/"
done < <(find "$SCOPE" -maxdepth 1 -type f \( -iname "*rule*" -o -iname "*规则*" \) | sort)

# kb 根也不该出现规则文件
if [ -n "$KB" ] && [ -d "$KB" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in README.md) continue ;; esac
    fail "kb 根出现规则文件：$base——规则归 a/b/c，材料进 decisions/facts/runbooks"
  done < <(find "$KB" -maxdepth 1 -type f \( -iname "*rule*" -o -iname "*规则*" \) | sort)
fi

# 客户端入口只允许短指针
for f in CLAUDE.md GEMINI.md CODEBUDDY.md; do
  [ -f "$SCOPE/$f" ] || continue
  size="$(wc -c < "$SCOPE/$f" | tr -d ' ')"
  if [ "$size" -gt 500 ] || ! grep -q "AGENTS.local.md" "$SCOPE/$f"; then
    fail "$f 不是有效指针（${size}B）：应 ≤500B 且指向 AGENTS.md / AGENTS.local.md"
  else
    pass "$f 是指针"
  fi
done

# ---- 忽略规则 ----
if [ -d "$SCOPE/.git" ]; then
  if git -C "$SCOPE" ls-files --error-unmatch AGENTS.local.md >/dev/null 2>&1; then
    fail "AGENTS.local.md 已被 git 跟踪"
  elif git -C "$SCOPE" check-ignore -q AGENTS.local.md 2>/dev/null; then
    if [ -f "$SCOPE/.gitignore" ] && grep -qxF '/AGENTS.local.md' "$SCOPE/.gitignore"; then
      pass "忽略写在 .gitignore（随仓库走）"
    else
      fail "只在 info/exclude 里忽略，克隆不带走；把 /AGENTS.local.md 加进 .gitignore"
    fi
  else
    fail "AGENTS.local.md 未被忽略，可能被提交"
  fi
fi

# ---- b 与路径文件的重复长句 ----
if [ -f "$B" ] && [ -f "$L" ]; then
  dups="$(comm -12 \
    <(awk 'length($0) >= 25 && $0 !~ /^[[:space:]]*[#>|-]/' "$B" | LC_ALL=C sort -u) \
    <(awk 'length($0) >= 25 && $0 !~ /^[[:space:]]*[#>|-]/' "$L" | LC_ALL=C sort -u))"
  if [ -n "$dups" ]; then
    warn "b 与路径文件有重复长句（应只留一处）：$(printf '%s\n' "$dups" | head -3 | cut -c1-40 | tr '\n' ';')"
  else
    pass "b 与路径文件无重复长句"
  fi
fi

# ---- a 层：主本是否分发 ----
SNIP="$HOME/.workbuddy/agent-memory-snippet.md"
if [ ! -f "$SNIP" ]; then
  warn "没找到 a 层主本：~/.workbuddy/agent-memory-snippet.md"
else
  stale=""
  for f in "$HOME/.codex/AGENTS.md" "$HOME/.workbuddy/AGENTS.md" "$HOME/.claude/CLAUDE.md"; do
    [ -f "$f" ] || continue
    [ "$SNIP" -nt "$f" ] && stale="$stale $(basename "$(dirname "$f")")/$(basename "$f")"
  done
  if [ -n "$stale" ]; then
    fail "a 层主本更新过但没分发（$stale）；跑 H:/AI工作区/agent-workspace-bridge/sync-agent-memory.ps1 -Update"
  else
    pass "a 层已分发（客户端文件不旧于主本）"
  fi
fi

echo "== 结果：FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
