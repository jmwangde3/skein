#!/usr/bin/env bash
# Skein v2.0.3 自动化冒烟测试（覆盖接手包完整性、老库收编、ai-memory 正常/失败显错与 BOM 校验）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/skein-cli"
chmod +x "$CLI"

TMP="$(mktemp -d "$ROOT/.smoke-tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0
ok() { PASS=$((PASS + 1)); printf '[PASS %02d] %s\n' "$PASS" "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

WS="$TMP/测试工作区"
DATA="$TMP/skein-data"
mkdir -p "$WS/sub-alpha" "$WS/sub-beta" "$WS/docs-only"
git -C "$WS/sub-alpha" init -q
git -C "$WS/sub-alpha" -c user.name=t -c user.email=t@local commit --allow-empty -q -m "init alpha"
git -C "$WS/sub-beta" init -q
git -C "$WS/sub-beta" -c user.name=t -c user.email=t@local commit --allow-empty -q -m "init beta"

# 1. init 建库（带 --trae）
"$CLI" init --workspace "$WS" --data "$DATA" --trae >/dev/null
[ -f "$WS/AGENTS.local.md" ] || fail "未生成 AGENTS.local.md"
[ -f "$WS/.trae/rules/project_rules.md" ] || fail "未生成 TRAE 规则"
[ -f "$DATA/测试工作区/kb/facts/projects/INDEX.md" ] || fail "未生成项目档案索引"
[ -f "$DATA/测试工作区/kb/facts/workspace-map.md" ] || fail "未生成工作区地图"
ok "中文路径建库、路由、地图、索引与 TRAE 规则生成成功"

# 2. 归属冲突拦截
WS2="$TMP/other/测试工作区"
mkdir -p "$WS2"
if "$CLI" init --workspace "$WS2" --data "$DATA" >/dev/null 2>&1; then
  fail "同名不同工作区未被 .skein-scope 拦截"
fi
ok "同名工作区归属冲突被正确拦截"

# 3. 老库收编（--adopt-existing）：无 .skein-scope 且无 facts/projects/ 的非空目录
LEGACY_WS="$TMP/老项目"
LEGACY_DATA="$TMP/legacy-data"
mkdir -p "$LEGACY_WS" "$LEGACY_DATA/老项目/kb/facts"
git -C "$LEGACY_WS" init -q
git -C "$LEGACY_WS" -c user.name=t -c user.email=t@local commit --allow-empty -q -m "legacy"
echo "# 旧事实" > "$LEGACY_DATA/老项目/kb/facts/old.md"
if "$CLI" init --workspace "$LEGACY_WS" --data "$LEGACY_DATA" >/dev/null 2>&1; then
  fail "未加 --adopt-existing 时不应接管无标记非空目录"
fi
"$CLI" init --workspace "$LEGACY_WS" --data "$LEGACY_DATA" --adopt-existing >/dev/null
[ -f "$LEGACY_DATA/老项目/.skein-scope" ] || fail "收编后未补 .skein-scope"
[ -f "$LEGACY_DATA/老项目/kb/facts/old.md" ] || fail "收编误删了旧知识库文件"
[ -f "$LEGACY_DATA/老项目/kb/facts/projects/INDEX.md" ] || fail "收编未补齐 projects/INDEX.md"
ok "老库 --adopt-existing 收编保护旧数据并补齐归属标记与档案索引"

# 4. check --strict 拦截缺档案，补齐 READY 档案后通过
if (cd "$WS/sub-alpha" && "$CLI" check --strict >/dev/null 2>&1); then
  fail "缺最小档案时 check --strict 不应通过"
fi
cat > "$DATA/测试工作区/kb/facts/projects/sub-alpha.md" <<'EOF'
# sub-alpha
- 状态：READY
- 仓库：sub-alpha
## 定位
测试子仓 [源码]
EOF
(cd "$WS/sub-alpha" && "$CLI" check --strict >/dev/null)
ok "check --strict 正确拦截缺档案并在补齐 READY 档案后通过"

# 5. 写前最小留痕 mark + 语义锚点 note + resume 含完整 PROJECT_BRIEF
(cd "$WS/sub-alpha" && "$CLI" mark --id "t-001" --goal "实现登录校验" --constraint "不引入新依赖" --next "写单测") >/dev/null
(cd "$WS/sub-alpha" && "$CLI" note --id "t-001" --type excluded "排除 JWT 方案：本地 CLI 无需无状态令牌") >/dev/null
(cd "$WS/sub-alpha" && "$CLI" note --id "t-001" --type hypothesis "假设本地配置均为 UTF-8") >/dev/null
res="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res" | grep -q "PROJECT_BRIEF (" || fail "resume 未输出最小档案"
echo "$res" | grep -q "TASK_ANCHOR: SINGLE (t-001)" || fail "单任务自动定位失败"
echo "$res" | grep -q "排除 JWT 方案" || fail "语义锚点未出现在 resume 输出中"
ok "写前留痕、语义锚点追加与完整接手包（含最小档案）通过"

# 6. ai-memory recent 正常调用与失败显错（禁止静默吞错）
MOCKBIN="$TMP/mockbin"
mkdir -p "$MOCKBIN"
cat > "$MOCKBIN/ai-memory" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "recent" ]; then
  echo "sessions/mock-001.md  2026-11-28T01:00:00Z"
  exit 0
fi
echo "unexpected args: $*" >&2
exit 2
EOF
chmod +x "$MOCKBIN/ai-memory"
res_am="$(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" resume)"
echo "$res_am" | grep -q "sessions/mock-001.md" || fail "resume 未正确调用 ai-memory recent"
(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" check --strict >/dev/null)

cat > "$MOCKBIN/ai-memory" <<'EOF'
#!/usr/bin/env bash
echo "error: mock failure" >&2
exit 2
EOF
chmod +x "$MOCKBIN/ai-memory"
res_am_err="$(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" resume)"
echo "$res_am_err" | grep -q "\[WARN_EXTERNAL_CAPTURE\]" || fail "ai-memory 报错被静默吞掉"
if (cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" check >/dev/null 2>&1); then
  fail "ai-memory 报错时 check 不应全绿"
fi
ok "ai-memory recent 正常拉取与失败显错（不静默吞错）均通过"

# 7. 多任务歧义拦截
(cd "$WS/sub-alpha" && "$CLI" mark --id "t-002" --goal "重构日志格式" --next "核对现有字段") >/dev/null
res2="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res2" | grep -q "TASK_ANCHOR: MULTIPLE (2" || fail "多任务歧义未触发提示"
ok "多任务歧义拦截通过"

# 8. 关闭任务后回到单任务
(cd "$WS/sub-alpha" && "$CLI" close "t-002") >/dev/null
res3="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res3" | grep -q "TASK_ANCHOR: SINGLE (t-001)" || fail "关闭任务后未回归单任务"
ok "任务归档与状态回归通过"

# 9. E5 活跃写入兜底探测
echo "bg-write" > "$WS/sub-alpha/bg_test.log"
res_bg="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res_bg" | grep -q "\[WARN_BG_ACTIVE\]" || fail "近期活跃写入未被 resume 检出"
echo "$res_bg" | grep -q "RECENT_WRITE" || fail "RECENT_WRITE 标记缺失"
rm -f "$WS/sub-alpha/bg_test.log"
ok "E5 工作树近期活跃写入兜底探测通过"

# 10. 并行 worktree 隔离与脏树防误删
wt_out="$(cd "$WS/sub-alpha" && "$CLI" wt-add "mod-a")"
wt_dir="$(printf '%s\n' "$wt_out" | sed -n 's/^WT_READY dir=\([^ ]*\).*/\1/p')"
[ -d "$wt_dir" ] && [ -f "$wt_dir/AGENTS.local.md" ] || fail "worktree 创建或路由复制失败"
echo "dirty" > "$wt_dir/uncommitted.txt"
if (cd "$WS/sub-alpha" && "$CLI" wt-clean "mod-a" >/dev/null 2>&1); then
  fail "脏 worktree 被误删"
fi
rm -f "$wt_dir/uncommitted.txt"
(cd "$WS/sub-alpha" && "$CLI" wt-clean "mod-a" >/dev/null)
[ ! -d "$wt_dir" ] || fail "干净 worktree 未清理"
ok "并行 worktree 隔离、脏树防误删与安全清理通过"

# 11. install.ps1 UTF-8 BOM 回归校验
bom="$(head -c 3 "$ROOT/install/install.ps1" | od -An -tx1 | tr -d ' \n')"
[ "$bom" = "efbbbf" ] || fail "install/install.ps1 缺少 UTF-8 BOM（当前前 3 字节：$bom）"
ok "install/install.ps1 为 UTF-8 带 BOM（兼容 PowerShell 5.1）"

# 12. 硬编码扫描
if grep -rnE "H:\\\\AI工作区|sync-agent-memory\.ps1|--agent codex|60%–75%|60%-75%" "$ROOT/bin" "$ROOT/skills" "$ROOT/templates" 2>/dev/null; then
  fail "检测到残留个人硬编码或过时规则"
fi
ok "无个人硬编码路径与过时规则残留"

printf '\n全部 %d 项冒烟测试通过！\n' "$PASS"
