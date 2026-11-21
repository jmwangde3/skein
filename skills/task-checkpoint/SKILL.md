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

`<checkpoints>` 与 store 都从项目根的 `AGENTS.local.md` 读（键 `checkpoints` / `store`）。读不到就报 `[HANDOFF_GAP]`，不要猜路径。

## 三层写入协议，顺序不许换

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -1 | tr -d '\r'; }
B="$(kv store)"; CKPT="$(kv checkpoints)"
[ -n "$B" ] && [ -n "$CKPT" ] || { echo "[HANDOFF_GAP] 缺 store / checkpoints 键"; exit 1; }

# 1. 读 rev（没文件就是 0）
grep '^checkpoint_rev:' "$CKPT/<task_id>.md"

# 2. 栅栏：不是我的任务就停
bd -C "$B" update <id> --if-assignee "$BEADS_ACTOR" --append-notes "checkpoint $(date +%H:%M)"

# 3. 整份重写，rev = 读到的值 + 1
# 4. 回读确认 rev 已是新值
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

**任务状态（owner / status / 依赖）不写进检查点**，实时读 `bd -C "$B" show <id>`。复制就是制造第二份真相。

## 长任务续租

租约 300 秒。任务超过 4 分钟就 `bd -C "$B" heartbeat <id>`。过期会被别人 `reclaim` 收走。

## 完成标志

最新快照落盘 + 回读确认 rev 递增；需要时 Beads 备注已更新或租约已续。
