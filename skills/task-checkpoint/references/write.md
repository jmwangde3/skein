# 检查点：写入协议与模板

写之前先把这里读完。`SKILL.md` 只讲什么时候写；具体怎么写在这里。

## 三层写入协议，顺序不许换

下面命令里的 `<task_id>` 是占位符，执行前换成真实值。**直接复制会报 `No such file or directory`**——bash 会把 `<xx>` 当成"从这个文件读输入"。

```bash
# 从当前目录向上找作用域根：第一个含 AGENTS.local.md 的目录
SCOPE=""
d="$(pwd -P)"
while :; do
  if [ -f "$d/AGENTS.local.md" ]; then SCOPE="$d"; break; fi
  p="$(dirname "$d")"
  if [ "$p" = "$d" ]; then break; fi
  d="$p"
done
[ -n "$SCOPE" ] || { echo "[HANDOFF_GAP] 没找到 AGENTS.local.md（应在工作区根）"; exit 1; }
LOCAL="$SCOPE/AGENTS.local.md"
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }
B="$(kv store)"; CKPT="$(kv checkpoints)"
[ -n "$CKPT" ] || { echo "[HANDOFF_GAP] 缺 checkpoints 键"; exit 1; }

# 这次干活的实际仓。一个工作区可能有多个仓，接手方必须知道该去哪个仓核对现场
REPO="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO" ] || REPO=none

TASK_ID="<task_id>"                 # 换成真实 ID
TARGET="$CKPT/$TASK_ID.md"
mkdir -p "$CKPT"

# 1. 读 rev（没有文件就是 0）
if [ -f "$TARGET" ]; then
  REV="$(sed -n 's/^checkpoint_rev:[[:space:]]*//p' "$TARGET" | head -n 1 | tr -d '\r ')"
else
  REV=0
fi
REV="${REV:-0}"; NEXT=$((REV + 1))

# 2. 栅栏：有 store 且装了 bd 才做；exit 13 = 任务已被别人接走
if [ -n "$B" ] && command -v bd >/dev/null 2>&1; then
  bd -C "$B" update "$TASK_ID" --if-assignee "$BEADS_ACTOR" \
     --append-notes "checkpoint $(date +%H:%M)" || {
    rc=$?; [ "$rc" -eq 13 ] && { echo "任务已被别人接走，停手重读"; exit 13; }; exit "$rc"; }
fi

# 3. 整份重写：先写独立的临时文件，YAML 里 checkpoint_rev 填 $NEXT，再替换
TMP="$TARGET.${BEADS_ACTOR:-local}.$$.tmp"
mv -f "$TMP" "$TARGET"

# 4. 回读断言
GOT="$(sed -n 's/^checkpoint_rev:[[:space:]]*//p' "$TARGET" | head -n 1 | tr -d '\r ')"
[ "$GOT" = "$NEXT" ] || { echo "[HANDOFF_GAP] rev 回读 $GOT，期望 $NEXT"; exit 1; }
```

- 第 2 步 **exit 13** = 任务已被别人接走，立即停手重读
- 第 3 步失败不要用旧 rev 重试，从第 1 步重来
- 发现文件里的 rev 比自己上次读到的大，说明别人写过，**先重读合并再写**

**第 2 步拦的是"这次 `bd update`"，不是整段写入。** 它通过之后、`mv` 之前仍有窗口：别人可能在这一刻强制转派并接手。独立临时文件能避免半截文件，但不是跨进程 CAS。真正防重叠写入靠的是"同一时刻只有一个写者 + 交接前确认旧写者已停"，`rev` 只是事后自检。

## 模板

```markdown
---
schema_version: 1
project: <项目名>
task_id: <bd 任务 ID>
checkpoint_rev: 1
writer: <最后写入者，审计用，不是 owner>
updated_at: <ISO 8601 带时区>
mode: ACTIVE
repo: <实际仓根绝对路径；当时不在任何仓里写 none>
worktree: <绝对路径>
branch: <分支名>
head: "<完整 HEAD SHA>"
dirty_files: []
untracked_files: []
---

## 任务目标
要交付什么，验收标准是什么。

## 当前进展
- 已完成（带证据：路径:行号 / 命令输出 / 提交号）
- 尚未完成

## 未验证与阻塞
- 未验证：写「没验证」，不写「应该没问题」
- 阻塞：
- 已知风险：

## 下一步（可直接执行）
1. 具体到命令或文件

## 不要重复
- 试过什么、为什么失败、什么条件下才值得再试

## 现场证据
- 命令输出 / 测试结果 / 关键日志摘要。文件清单以头部 `head` / `dirty_files` / `untracked_files` 为准，不要重复抄一遍

## 待写入长期知识
- 新事实及来源 / 新决策及理由

## 规则在哪
- 全局：<用户级规则文件路径>；没有写「无」
- 工作区：`AGENTS.md`；没有写「无」
- 项目：`<仓>/AGENTS.md`；没有写「无」
- 路径：`AGENTS.local.md`（kb=<库绝对路径>）；只放路径，不是规则层
- 本次改过的规则：<哪一层、改了什么>；没改写「无」

## 验收标准
- [ ] 目标完成
- [ ] 必要验证通过
- [ ] 风险已说明
```

`repo` 和 `worktree` 分工：`worktree` 是这次真正动代码的目录（并行时是独立工作树），`repo` 是它属于哪个仓。`worktree` 为空时接手方去 `repo` 里核对现场；`repo` 是 `none` 说明当时不在任何仓里，接手方不许虚构 HEAD。

`mode` 四种取值：

- 正常交棒：`ACTIVE` → 交出前 `HANDOFF_READY` → 接手方核对后 `RECEIVED` → 开始执行「下一步」第 1 条改回 `ACTIVE` → 验收通过、任务关闭后 `CLOSED`
- 主动接管：`ACTIVE` 可以直接转 `RECEIVED`，但那一份是**半截快照**，接手方必须对着 Git 现场核实，不能照抄「下一步」

别停在中间态。

**任务状态（owner / status / 依赖）不写进检查点**，实时读 `bd -C "$B" show <id>`。复制就是制造第二份真相。

## 长任务续租

租约 300 秒。有 `store` 且装了 `bd` 时，任务超过 4 分钟就 `bd -C "$B" heartbeat <id>`，过期会被别人 `reclaim` 收走；没有 `store` 或没有 `bd` 时跳过这一步，只更新检查点的时间戳。

## 写完自检

- [ ] 头部字段齐全（`schema_version` 到 `untracked_files`），`head` 是完整 SHA 不是缩写，`repo` 不是空的
- [ ] `checkpoint_rev` 比上次大 1，回读一致
- [ ] 「下一步」第 1 条能直接执行，不用再判断
- [ ] 「不要重复」里至少有一条避坑记录（没有就写"无"）
- [ ] 「规则在哪」四条写的是真实路径；改过规则的话，旧条目已合并或删除
- [ ] 没把任务状态复制进来
