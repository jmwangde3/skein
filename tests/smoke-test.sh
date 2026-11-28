#!/usr/bin/env bash
# Skein v2.0.6 自动化冒烟测试（覆盖接手包完整性、老库收编、ai-memory 正常/失败显错与 BOM 校验）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT/bin/skein-cli"
chmod +x "$CLI"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/skein-smoke.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# Use local fixtures even when the workstation has a running capture service.
mkdir -p "$TMP/mockbin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/mockbin/ai-memory"
chmod +x "$TMP/mockbin/ai-memory"
export PATH="$TMP/mockbin:$PATH"

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
cat > "$LEGACY_WS/AGENTS.md" <<'LEG'
# 老项目规则
<!-- skein-rules -->
## 自定义收尾纪律
- 保留我自己的自定义规则
<!-- /skein-rules -->
LEG
if "$CLI" init --workspace "$LEGACY_WS" --data "$LEGACY_DATA" >/dev/null 2>&1; then
  fail "未加 --adopt-existing 时不应接管无标记非空目录"
fi
"$CLI" init --workspace "$LEGACY_WS" --data "$LEGACY_DATA" --adopt-existing >/dev/null
[ -f "$LEGACY_DATA/老项目/.skein-scope" ] || fail "收编后未补 .skein-scope"
[ -f "$LEGACY_DATA/老项目/kb/facts/old.md" ] || fail "收编误删了旧知识库文件"
[ -f "$LEGACY_DATA/老项目/kb/facts/projects/INDEX.md" ] || fail "收编未补齐 projects/INDEX.md"
grep -q "保留我自己的自定义规则" "$LEGACY_WS/AGENTS.md" || fail "--adopt-existing 静默覆盖了自定义 skein-rules 块"
"$CLI" init --workspace "$LEGACY_WS" --data "$LEGACY_DATA" --adopt-existing --update-rules >/dev/null
grep -q "Skein v2 工作纪律" "$LEGACY_WS/AGENTS.md" || fail "--update-rules 未更新规则块"
ls "$LEGACY_DATA/老项目/backups"/AGENTS.md.*.bak >/dev/null 2>&1 || fail "--update-rules 更新前未自动备份 AGENTS.md"
ok "老库 --adopt-existing 默认保留自定义规则，--update-rules 自动备份后更新"

# A generated-file refresh must preserve unrelated work and staging state.
kb="$DATA/测试工作区/kb"
echo "草稿" > "$kb/facts/draft.md"
git -C "$kb" add -- facts/draft.md
echo "新草稿" > "$kb/facts/pending.md"
echo "地图变化" > "$WS/extra.txt"
"$CLI" init --workspace "$WS" --data "$DATA" >/dev/null
git -C "$kb" diff --cached --name-only | grep -qx 'facts/draft.md' || fail "刷新吞掉已暂存草稿"
if git -C "$kb" ls-files --error-unmatch facts/pending.md >/dev/null 2>&1; then fail "刷新提交无关文件"; fi
ok "刷新知识库仅提交工具生成的文件"

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

(cd "$WS/sub-alpha" && "$CLI" mark --goal "实现登录校验" --next "另一第一步") >/dev/null
again="$(cd "$WS/sub-alpha" && "$CLI" resume --full)"
grep -q '排除 JWT 方案' <<< "$again" && grep -q '本地配置均为 UTF-8' <<< "$again" || fail "重复 mark 丢失语义记录"
(cd "$WS/sub-alpha" && "$CLI" note --type goal "只检查登录校验") >/dev/null
(cd "$WS/sub-alpha" && "$CLI" note --type next "审查入口") >/dev/null
compact="$(cd "$WS/sub-alpha" && "$CLI" resume)"
grep -q '只检查登录校验' <<< "$compact" && grep -q '审查入口' <<< "$compact" || fail "摘要漏掉最新目标或下一步"
if grep -q '实现登录校验' <<< "$compact"; then fail "摘要返回旧目标"; fi
ok "重复 mark 保留历史，简报选择最新目标与下一步"

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
echo 'INFO ai_memory_cli: ai-memory starting version="3.6.3"' >&2
echo 'Error: GET /admin/recent: server returned 404 Not Found: {"error":"project '''sub-alpha''' not found in workspace '''default'''"}' >&2
exit 1
EOF
chmod +x "$MOCKBIN/ai-memory"
res_am_404="$(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" resume)"
echo "$res_am_404" | grep -q "尚未产生首次捕获记录" || fail "新项目 ai-memory 404 未优雅提示"
(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" check --strict >/dev/null)

cat > "$MOCKBIN/ai-memory" <<'EOF'
#!/usr/bin/env bash
echo 'INFO ai_memory_cli: ai-memory starting version="3.6.3"' >&2
echo "Error: connection refused" >&2
exit 2
EOF
chmod +x "$MOCKBIN/ai-memory"
res_am_err="$(cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" resume)"
echo "$res_am_err" | grep -q "\[WARN_EXTERNAL_CAPTURE\]" || fail "ai-memory 真报错被静默吞掉"
echo "$res_am_err" | grep -q "connection refused" || fail "ai-memory 未提取真实 Error 行"
if (cd "$WS/sub-alpha" && PATH="$MOCKBIN:$PATH" "$CLI" check >/dev/null 2>&1); then
  fail "ai-memory 真报错时 check 不应全绿"
fi
ok "ai-memory 三态（正常 / 新项目404放行 / 真报错显错）均通过"

# Ensure long-running anchors stay short, while full history remains recoverable.
for n in 1 2 3 4 5; do
  (cd "$WS/sub-alpha" && "$CLI" note --type decision "历史判断-$n") >/dev/null
done
compact="$(cd "$WS/sub-alpha" && "$CLI" resume)"
full="$(cd "$WS/sub-alpha" && "$CLI" resume --full)"
grep -q '历史判断-1' <<< "$full" && grep -q '历史判断-5' <<< "$compact" || fail "历史或新判断缺失"
if grep -q '历史判断-1' <<< "$compact"; then fail "简报超出每类记录上限"; fi
grep -q 'resume --full' <<< "$compact" || fail "摘要未提示截断"

# 7. 多任务歧义拦截
(cd "$WS/sub-alpha" && "$CLI" mark --id "t-002" --goal "重构日志格式" --next "核对现有字段") >/dev/null
res2="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res2" | grep -q "TASK_ANCHOR: MULTIPLE (2" || fail "多任务歧义未触发提示"
grep -q 't-001 | 只检查登录校验' <<< "$res2" || fail "候选列表使用了旧目标"
ok "多任务歧义拦截通过"

# 8. 关闭任务后回到单任务
(cd "$WS/sub-alpha" && "$CLI" close "t-002") >/dev/null
res3="$(cd "$WS/sub-alpha" && "$CLI" resume)"
echo "$res3" | grep -q "TASK_ANCHOR: SINGLE (t-001)" || fail "关闭任务后未回归单任务"
ok "任务归档与状态回归通过"

# A finished write must not trigger the "wait or terminate" gate.
echo "finished" > "$WS/sub-alpha/bg_test.log"
res_bg="$(cd "$WS/sub-alpha" && "$CLI" resume)"
if grep -qF '[WARN_BG_ACTIVE]' <<< "$res_bg"; then fail "一次保存误报正在写入"; fi
if ! grep -q 'write_probe: unavailable' <<< "$res_bg"; then
  # Stop the fixture even if a probe fails; it never writes outside TMP.
  (
    while [ -e "$WS/sub-alpha/bg_test.log" ]; do
      printf 'x' >> "$WS/sub-alpha/bg_test.log"
      sleep 0.05
    done
  ) &
  writer_pid=$!
  active="$(cd "$WS/sub-alpha" && "$CLI" resume)" || { kill "$writer_pid" 2>/dev/null || true; fail "写入采样失败"; }
  kill "$writer_pid" 2>/dev/null || true
  wait "$writer_pid" 2>/dev/null || true
  grep -qF '[WARN_BG_ACTIVE]' <<< "$active" || fail "漏检连续写入"
fi
rm -f "$WS/sub-alpha/bg_test.log"
ok "区分已完成的保存与采样期间的持续写入"

# 10. 并行 worktree 隔离与脏树防误删
wt_out="$(cd "$WS/sub-alpha" && "$CLI" wt-add "mod-a")"
wt_dir="${wt_out#*WT_READY dir=}"; wt_dir="${wt_dir% branch=*}"
[ -d "$wt_dir" ] && [ -f "$wt_dir/AGENTS.local.md" ] || fail "worktree 创建或路由复制失败"
wt_out2="$(cd "$WS/sub-alpha" && "$CLI" wt-add "mod-b")"
wt_dir2="${wt_out2#*WT_READY dir=}"; wt_dir2="${wt_dir2% branch=*}"
(cd "$wt_dir" && "$CLI" mark --goal "模块 A" --next "A1") >/dev/null
(cd "$wt_dir2" && "$CLI" mark --goal "模块 B" --next "B1") >/dev/null
wa="$(cd "$wt_dir" && "$CLI" resume)"
wb="$(cd "$wt_dir2" && "$CLI" resume)"
for packet in "$wa" "$wb"; do
  grep -q 'PROJECT_BRIEF (' <<< "$packet" || fail "worktree 未找到原项目档案"
  grep -q 'TASK_ANCHOR: SINGLE' <<< "$packet" || fail "worktree 未匹配唯一任务"
done
grep -q '模块 A' <<< "$wa" && grep -q '模块 B' <<< "$wb" || fail "worktree 任务不匹配"
if grep -q '模块 B' <<< "$wa" || grep -q '模块 A' <<< "$wb"; then fail "worktree 串任务"; fi
lock="$(git -C "$wt_dir" rev-parse --path-format=absolute --git-path index.lock)"
touch "$lock"
locked="$(cd "$wt_dir" && "$CLI" resume)"
other="$(cd "$wt_dir2" && "$CLI" resume)"
rm -f "$lock"
grep -q 'GIT_INDEX_LOCK:' <<< "$locked" || fail "漏检 linked worktree 的锁"
if grep -q 'GIT_INDEX_LOCK:' <<< "$other"; then fail "误报其他工作树的锁"; fi
(cd "$WS/sub-alpha" && "$CLI" wt-clean "mod-b") >/dev/null
ok "独立 worktree 各自恢复，读取原项目档案并区分真实索引锁"
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

# 13. 技能 references 引用完整性校验（防止悬空引用）
for sk in "$ROOT"/skills/*/SKILL.md; do
  dir="$(dirname "$sk")"
  for ref in $(grep -oE 'references/[A-Za-z0-9_.-]+\.md' "$sk" 2>/dev/null | sort -u); do
    [ -f "$dir/$ref" ] || fail "悬空引用：$sk -> $ref 不存在"
  done
done
ok "全部 Skill 的 references 引用均真实存在"

printf '\n全部 %d 项冒烟测试通过！\n' "$PASS"
