---
name: task-checkpoint
description: 单 Agent 长任务做到一半、上下文到 60%–75%、即将被压缩、或要停机换手时加载，把现场落盘成检查点并续租。触发：checkpoint、落盘、断点、续接、heartbeat、compaction 后恢复。
---

# task-checkpoint

## 只做这一件事

把「现在做到哪、下一步做什么」写成一份陌生人也能读懂的检查点，并在长任务里续租。

**不做**：转派任务（`agent-handoff`）、合并分支（`agent-collab`）、整理知识库（`project-memory`）。

## 什么时候写

- 完成一个可验证的阶段结果
- 做了会推翻旧做法的决策
- 遇到阻塞、踩了坑
- 上下文到 **60%–75%**，或马上要被压缩（50% 起就该留意）
- 要停下来（换天、换 agent、吃饭）

**不写**：每条命令的流水账、「继续中」、源码里直接能看出来的东西。

**上下文被压缩后第一件事是重读检查点**，不是接着干。压缩会丢掉细节但留下「我记得做过」的错觉，这时最容易重复劳动。重读「已完成 / 不要重复 / 下一步」三节再决定动作。

## 写到哪

`<checkpoints>/<task_id>.md`，一任务一文件，每次覆盖为最新快照。

两个键都从项目根的 `AGENTS.local.md` 读：

- **`checkpoints`** —— 必需。缺了就报 `[HANDOFF_GAP]`，不要猜路径
- **`store`** —— 可选。有它且装了 `bd`，才做归属栅栏和续租；没有就只写文件。一个 agent 长期自己跑，不需要 Beads

任务 ID 用 `bd` 的 ID；没装 Beads 时自己起一个 `local-<日期>-<短名>`，同一任务始终用同一个。

## 三层写入协议，顺序不许换

下面命令里的 `<task_id>` 是占位符，执行前换成真实值。**直接复制会报 `No such file or directory`**——bash 会把 `<xx>` 当成"从这个文件读输入"。

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }
B="$(kv store)"; CKPT="$(kv checkpoints)"
[ -n "$CKPT" ] || { echo "[HANDOFF_GAP] 缺 checkpoints 键"; exit 1; }

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

# 3. 整份重写：先写 "$TARGET.tmp"，YAML 里 checkpoint_rev 填 $NEXT
mv -f "$TARGET.tmp" "$TARGET"

# 4. 回读断言
GOT="$(sed -n 's/^checkpoint_rev:[[:space:]]*//p' "$TARGET" | head -n 1 | tr -d '\r ')"
[ "$GOT" = "$NEXT" ] || { echo "[HANDOFF_GAP] rev 回读 $GOT，期望 $NEXT"; exit 1; }
```

- 第 2 步 **exit 13** = 任务已被别人接走，立即停手重读
- 第 3 步失败不要用旧 rev 重试，从第 1 步重来
- 发现文件里的 rev 比自己上次读到的大，说明别人写过，**先重读合并再写**

**`checkpoint_rev` 是自检不是锁。** 拦得住守规则、照 rev 写的写者；拦不住直接覆盖文件的写者。

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
- HEAD / 修改文件 / 未跟踪文件 / 测试输出

## 待写入长期知识
- 新事实及来源 / 新决策及理由

## 验收标准
- [ ] 目标完成
- [ ] 必要验证通过
- [ ] 风险已说明
```

`mode`：`ACTIVE` / `HANDOFF_READY` / `RECEIVED` / `CLOSED`。

流转只有一条线：开工或续写 `ACTIVE` → 交出前 `HANDOFF_READY` → 接手核对后先 `RECEIVED`，开始执行「下一步」第 1 条时改回 `ACTIVE` → 验收通过、任务关闭后 `CLOSED`。别停在中间态。

**任务状态（owner / status / 依赖）不写进检查点**，实时读 `bd -C "$B" show <id>`。复制就是制造第二份真相。

## 长任务续租

租约 300 秒。有 `store` 且装了 `bd` 时，任务超过 4 分钟就 `bd -C "$B" heartbeat <id>`，过期会被别人 `reclaim` 收走；没有 `store` 或没有 `bd` 时跳过这一步，只更新检查点的时间戳。

## 完成标志

最新快照落盘 + 回读确认 rev 递增；需要时 Beads 备注已更新或租约已续。
