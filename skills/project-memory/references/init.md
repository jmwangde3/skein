# 接入一个工作区并建库

这是**唯一**的建库入口。具体动作由技能目录里的 `scripts/init.sh` 完成——脚本跟着技能一起部署，不依赖机器上有没有 Skein 源码仓。

## 两种用法，结果不同

**用技能（完整建库）**：在工作区根对 AI 说「用 project-memory 给这个工作区建库，数据放 `D:/skein-data`」。AI 读本文件，先跑脚本，再按「逐仓建档」把每个 git 仓写成一份档案。

**自己跑脚本（只有骨架）**：在终端里执行同一条命令，技能目录换成你客户端的真实位置：

```bash
bash ~/.claude/skills/project-memory/scripts/init.sh \
  --workspace "D:/work/我的工作区" \
  --data "D:/skein-data"
```

脚本建目录、路由、知识库骨架、机械地图和档案索引，**但不写任何项目档案**——档案索引里每个仓都会停在 `TODO`。

**两者不等价。** 脚本只能读文件系统和 Git 元数据，读不出「这个仓解决什么问题、从哪进、怎么跑」。这些必须由 agent 读少量文件后写。只跑脚本 = 库能用、但新 agent 接手仍需自己摸一遍。

## 先找到脚本

技能可能被手工复制时漏了文件。按顺序找，命中就停：

```bash
INIT=""
for d in "$PWD/.claude/skills" "$PWD/.codex/skills" "$PWD/.workbuddy/skills" \
         "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.workbuddy/skills"; do
  if [ -f "$d/project-memory/scripts/init.sh" ]; then INIT="$d/project-memory/scripts/init.sh"; break; fi
done
[ -n "$INIT" ] || { echo "[HANDOFF_GAP] 找不到 scripts/init.sh，技能可能装漏了文件"; exit 1; }
```

都找不到 → 报 `[HANDOFF_GAP]` 并停下。**不要凭记忆手写建库命令**——那就又变成两份实现，迟早对不上。

## 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `--workspace <目录>` | 当前目录 | 工作区根，可以包含多个 git 仓 |
| `--data <目录>` | `~/skein-data` | 数据家；也可以设 `SKEIN_DATA_HOME` |
| `--prefix <前缀>` | `sk` | 任务库前缀，只在装了 `bd` 时用 |

路径用正斜杠，Windows 也写 `D:/skein-data`。脚本会自己把 `/c/...` 转成 `C:/...` 再写进路由。

## 它做什么

1. 从工作区根向下扫一遍：子目录里还有 `AGENTS.local.md` 就**停下并列出清单**，等用户决定（它不会删别人的路由）
2. 建 `<数据家>/<工作区名>/{store,checkpoints,backups,worktrees}`
3. 建 `kb/{facts,decisions,runbooks,journal,proposals,archive}`
4. 写归属标记 `.skein-scope`（内容是工作区绝对路径）
5. 工作区根没有 `AGENTS.local.md` 才写；已有就沿用并只核对键
6. 工作区根**本身是 git 仓**时，把 `AGENTS.local.md` 写进 `.git/info/exclude`
7. `kb` 独立 `git init`，写首版 `INDEX.md` / `current.md`
8. 生成工作区地图 `kb/facts/workspace-map.md`（顶层不足 3 项就跳过）
9. 生成项目档案索引 `kb/facts/projects/INDEX.md`：每个 git 仓一行，状态全标 `TODO`
10. 装了 `bd` 就 `bd init`，没装就提示怎么补

## 工作区地图

建库时会顺手写一张 `kb/facts/workspace-map.md`，给第一次进这个工作区的人看的：

| 条目 | 类型 | 最后提交 | 顶层条目数 | 备注 |
|---|---|---|---:|---|
| `web-first-ask-browser-mode` | git 仓 | 2026-11-20 | 24 | package.json: web-first-ask@0.2.1 |
| `mcp-shared-browser-release` | git 仓 | 2026-11-19 | 15 | package.json: chatgpt-web-mcp@0.7.13 |
| `token-bench-20261116` | 目录 | - | 12 | 无 |

规则就这么几条：

- **只扫顶层一层，不含隐藏项**，跳过 `node_modules` / `.venv` / `dist` / `build` / `target` / 符号链接
- **不算递归体积**：一个 40 MB 的目录 `du -sh` 要 20 秒，五个就能把建库拖到两分钟。改成「顶层条目数」，同样能看出哪些目录异常臃肿
- **备注只做机械摘取**：先 `package.json` 的 `name@version`（同名副本靠它区分），再 `README.md` 的第一个正文行（`#` 标题也认），都没有写「无」
- **有效条目少于 3 个就不生成**，只有一两个目录时 `ls` 更快
- **文件是生成的，不要手工改**，重跑 `init.sh` 会覆盖；要补用途写 `facts/workspace-notes.md`
- 单独刷新不用重跑整个建库：`bash <技能目录>/project-memory/scripts/map.sh --workspace <工作区>`

地图是**快照，不是当前事实**。文件头写了生成时间；agent 要动手前仍要核对目标目录和 `git rev-parse HEAD`，冲突时以现场为准。

## 逐仓建档（脚本做不了这一段）

脚本跑完只是骨架。要让人能直接接手，还得给每个 git 仓写一份档案。

规则、模板、上限、黑名单全在 `references/brief.md`，这里只说流程。

### 顺序

1. 读 `kb/facts/projects/INDEX.md`，取出所有状态为 `TODO` 的行
2. 逐仓判断要不要读代码（分档规则见 `brief.md`）：
   - 当前任务涉及这个仓 → 完整建档
   - 工作树有未提交改动 → 完整建档
   - 任一本地分支 90 天内有提交 → 完整建档
   - 都不满足 → 简化建档，只写头部 + 定位 + 文档指针，状态 `PARTIAL`
3. 完整建档按这个顺序读，**读到能填满字段就停，不要继续深挖**：
   - `README.md`：前 60 行，找「是什么」和「怎么跑」
   - `package.json` / `pyproject.toml` / `Makefile` / `Cargo.toml`：只取 scripts / test / build 相关键
   - 目录结构：只看两层，不列全量
   - 最多 3 个入口文件：只读开头 40 行，确认它是不是入口
4. 写 `<仓名>.md.tmp` → 校验（必填字段、≤ 4 KB / 70 行）→ 改名为正式文件
5. 改 `INDEX.md` 的状态与基线
6. `git -C <kb> commit -m "kb: 建档 <仓名>"`

### 预算

- 单仓累计摘取 **不超过 8 KiB 文本**。超了就停，没读的部分写进「缺口」
- 读大文件前先看行数；超过 400 行只读前 40 行 + 目录

### 完成判据

```bash
grep -c '| TODO |' "$KB/facts/projects/INDEX.md"    # 应为 0
```

不为 0 就是「库已建、档案未建」。**接手方看到 `TODO` 或 `PARTIAL` 必须知道这不是就绪状态**：`TODO` 要现场摸，`PARTIAL` 要补缺口。

### 中断了怎么办

建到一半停下是正常的（上下文用完、用户走了）。恢复时**先看文件，再看索引**：

- 索引写 `READY` 但文件不存在或字段不全 → 改回 `TODO`
- 索引写 `TODO` 但文件完整 → 核对后改成真实状态
- 有 `.tmp` 残留 → 删掉重写，不要续写

细节在 `brief.md` 的「写入与中断恢复」。

### 多仓工作区

8 个仓就是 8 次循环，**每次独立写盘并提交**。不要攒到最后一起写——中途断掉会全丢。

只建了常用的那个仓、其余仍是 `TODO`，是允许的中间状态，但要在 `current.md` 里写清「已建 X，未建 Y」。

## 它会拒绝的情况

拒绝时输出 `[HANDOFF_GAP]`，退出码 1，**不改任何东西**：

| 情况 | 为什么拒绝 |
|---|---|
| 子目录里还有 `AGENTS.local.md` | 会遮住工作区这份，必须先由用户决定去留 |
| 数据家落在 git 工作树里 | 私有库会被提交、可能被推送 |
| 数据目录已属于另一个同名工作区 | 两个「项目」会共用一份库（看 `.skein-scope`） |
| 数据目录有内容但没有归属标记 | 来历不明，不接管 |
| `kb` 已配置远程 | 私有库不该有远程 |
| `AGENTS.local.md` 已被 git 跟踪 | 忽略规则对已跟踪文件无效，先 `git rm --cached` |

## 验收

| 项 | 命令 | 期望 |
|---|---|---|
| 路由 | `cat <工作区>/AGENTS.local.md` | 五个键都有值，路径是 `C:/...` 或 `/home/...` |
| 作用域唯一 | `find <工作区> -mindepth 2 -name AGENTS.local.md` | 无输出 |
| 忽略 | 工作区是仓根时 `git check-ignore -v AGENTS.local.md` | 有一行输出 |
| 归属 | `cat <数据家>/<工作区名>/.skein-scope` | 等于工作区绝对路径 |
| 库独立 | `git -C <kb> remote -v` | 无输出 |
| 库已提交 | `git -C <kb> log --oneline` | 至少一条 |
| 任务库 | `bd -C <store> list` | 不报错（没装 bd 可跳过） |
| 地图 | `head -8 <kb>/facts/workspace-map.md` | 有生成时间和表格；顶层不足 3 项时没有这个文件 |
| 档案索引 | `cat <kb>/facts/projects/INDEX.md` | 每个 git 仓一行；状态列是 `TODO` / `PARTIAL` / `READY` |
| 档案齐否 | `grep -c '\| TODO \|' <kb>/facts/projects/INDEX.md` | `0` = 全部建完；大于 0 = 还有仓没建档 |

再让 AI 说一句：「读一下 `AGENTS.local.md`，告诉我 store 和 kb 在哪。」说得对就通了。

## 建库之后

库的内容（分类、事实、决策、真实提交）归本技能继续管，脚本只建骨架：

- **项目档案**：改过入口、命令或约束，用 `brief.md` 的刷新规则按需更新；`HEAD` 变了但引用文件没变，不用动
- 新事实写 `facts/`，新决策写 `decisions/`，可复用步骤写 `runbooks/`
- `INDEX.md` 超过 1000 tokens 就该整理，读 `references/curate.md`
- 旧库搬进来读 `references/migration.md`

## 常见错误

- **给每个 git 仓都建一个库。** 库是按工作区建的；子仓共享同一份，任务标题带 `[子仓名]` 区分
- **在子目录又放一份 `AGENTS.local.md`。** 会遮住工作区那份，技能向上找时就停了
- **让安装脚本顺手建库。** `install.sh` 只复制技能，建库只走这里
- **两个同名工作区共用一个数据目录。** 比如 `D:/a/项目` 和 `E:/b/项目`；`.skein-scope` 会拦住，换 `--data` 即可，别手工删标记
- **手工往地图里加备注。** 下次 `init.sh` 会把整张表覆盖掉；说明写到 `facts/workspace-notes.md`
- **把档案写成第二份 README。** 超过 4 KB / 70 行就是写多了，细节留指针，不复制正文
- **只跑脚本就以为建完了。** 档案索引还是 `TODO` 就说明没建完，新 agent 接手仍要现场摸
