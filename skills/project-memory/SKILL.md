---
name: project-memory
description: 需要按需检索项目知识库、回读某个结论的原文、把新事实写回、给一个工作区建库/接入、迁库或整理时加载。触发：查知识库、翻历史决策、写回、建库、接入工作区、迁移、整理。
---

# project-memory

## 只做这一件事

在**不整份加载**的前提下，从知识库拿到需要的那一段；把新产生的事实与决策写回去。

**不做**：不碰任务状态（Beads）、不碰检查点（`task-checkpoint`）、不做语义自动合并。

**建库和接入工作区都归这一个技能。** 别的技能只读库，不建库；`install.sh` 只复制技能，不碰项目目录。实际动作由技能目录里的 `scripts/init.sh` 完成——技能调用它，用户也可以直接跑它，同一份实现。

## 库在哪：向上找作用域

```bash
SCOPE=""
d="$(pwd -P)"
while :; do
  if [ -f "$d/AGENTS.local.md" ]; then SCOPE="$d"; break; fi
  p="$(dirname "$d")"
  if [ "$p" = "$d" ]; then break; fi
  d="$p"
done
[ -n "$SCOPE" ] || { echo "[HANDOFF_GAP] 没找到 AGENTS.local.md（应在工作区根）"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$SCOPE/AGENTS.local.md" | head -n 1 | tr -d '\r'; }
KB="$(kv kb)"
[ -n "$KB" ] || { echo "[HANDOFF_GAP] 缺 kb 键"; exit 1; }
```

**作用域 = 一个目录，可以包含多个 git 仓。** 一个工作区一套库，不是一仓一套。子目录里再放 `AGENTS.local.md` 会遮住工作区那份。

## 检索阶梯：从便宜到贵，命中就停

| 级 | 动作 | 用在 |
|---|---|---|
| 1 | 读 `INDEX.md` + `current.md` | 定位到 1–2 个文件 |
| 2 | `es -path "$KB" "<文件名片段>" -n 20 -export-json <tmp>` | 只记得文件名、不记得内容 |
| 3 | `rg -n "<词>" INDEX.md current.md facts decisions runbooks` | 已知术语、函数名、错误码 |
| 4 | `qmd search "<词>" -c skein-kb -n 5` | 换词、跨文件（**50 篇以上才开**） |
| 5 | `qmd get <file>:<from>:<count>` | 回读命中段 |
| 6 | `qmd vsearch` | 概念模糊、前几级全漏 |

**禁止**：开局 `cat` 整个文件、把 `archive/` 纳入常规检索、一次返回几十条。

细节与坑（`es` 的 GBK 问题、`qmd` 的 mask 铁律、工具缺失时怎么降级）在 `references/search.md`。

## 写入：全库单写者

同一时刻只有一个 agent 直接写 `kb/`。**并行开工前由发起方点名指定写者**，写者写满整个并行期；交接时写者身份随检查点一起交给下一个人。**主动接管只在旧写者确认停止后才转移写权**——改派任务不会让 A 停下笔。没点名就等于没写者，此时谁也不许直接改库。

其他人写 `proposals/`，文件名带上子项目，免得两个仓用同一个主题撞车：

```
proposals/<日期>-<子项目>-<主题>.md
改哪个文件：
改什么：
为什么：
证据：
```

由写者合并，写完立刻 commit。

**为什么必须这样**：Git 只报「同段冲突」。改不同文件不冲突；改同一文件不同行自动合并且不报错——语义覆盖会静默发生，事后查不出来。

## 四个 references，按需读

| 文件 | 什么时候读 |
|---|---|
| `references/init.md` | **接入一个新工作区、建库**（唯一入口，调 `scripts/init.sh`） |
| `references/search.md` | 要完整命令、`es` 乱码、`qmd` mask 报错、判断该不该开 QMD |
| `references/migration.md` | 旧库迁进来 |
| `references/curate.md` | `INDEX.md` 超 1000 tokens、`facts/` 出现矛盾、`journal/` 超 200 行 |

## 完成标志

- 检索：能贴出命中的原文片段与文件路径，不是「我记得有」
- 写回：`git log` 里有一条对应提交，`INDEX.md` 能定位到新文件
- 建库：按 `references/init.md` 的验收表逐项过一遍（含 `facts/workspace-map.md`），全绿才算完成
