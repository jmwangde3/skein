# Skein · 一绞线

> **给 AI 助手用的四件套：打结、接续、织存、并线。**
> 你不需要会写代码。会复制粘贴、会看文件夹，就能用。

Skein（读作"斯肯"，/skeɪn/）是英文里"一绞线"的意思。一次任务是一绞线，打一个结记住做到哪，交给下一个人时接上，几绞线可以并着织。

这套东西**不是软件**，是四份写给 AI 助手看的工作规程，外加几个模板和安装脚本。你把它们放进 AI 的"技能目录"，AI 在对应场景就会自己翻出来照做。

**最短路径（只装技能，3 分钟）：**

1. 装 [Git for Windows](https://git-scm.com/download/win)
2. 右上角 Code → Download ZIP，解压
3. 打开 Git Bash，执行 `bash install/install.sh --client all`

装完重启 AI 客户端即可。要建库，看[第 5 节](#5-建库给一个工作区接上)。

---

## 目录

1. [这是什么](#1-这是什么)
2. [基于哪些需求做的](#2-基于哪些需求做的)
3. [能做到什么，做不到什么](#3-能做到什么做不到什么)
4. [安装](#4-安装)
5. [建库：给一个工作区接上](#5-建库给一个工作区接上)
6. [怎么使用](#6-怎么使用)
7. [日常问题怎么解决](#7-日常问题怎么解决)
8. [文件都放在哪](#8-文件都放在哪)
9. [许可与依赖](#9-许可与依赖)

---

## 1. 这是什么

AI 助手有一个绕不开的毛病：**它的记性只在一个窗口里有效。**

- 一个活干到一半，窗口关了，第二天要重新讲一遍背景
- 换一个助手接手，它不知道前面的人做到哪、试过什么、什么不能再试
- 两个助手同时干一个项目，互相把文件改成对方不认识的样子
- 上周讨论出来的结论，这周又从头讨论一遍

现实里的解决办法很朴素：**交接班记录本、档案柜、排班表。** Skein 就是把这三样东西做成 AI 能读的格式。

四个技能，各管一件事：

| 环节 | 技能名 | 用一句人话说 | 什么时候会自动出现 |
|---|---|---|---|
| 打结 | `task-checkpoint` | 把"做到哪、下一步、别重复什么"写成一张纸 | 长任务做到一半、快记不住的时候 |
| 接续 | `agent-handoff` | 换人接手时，怎么核对、怎么交接 | 你说"换个助手接手"或开新窗口 |
| 织存 | `project-memory` | 从档案柜里只抽出需要那一页 | 你说"以前是不是定过…" |
| 并线 | `agent-collab` | 两个人同时干，怎么不打架 | 只有真的要并行时才挂，干完就卸 |

**关键设计：四个技能互不重叠。** 每个技能都要占用 AI 的一点"注意力"，所以宁可拆细、按需挂载，也不要一个大而全的技能天天挂着。

---

## 2. 基于哪些需求做的

这些不是拍脑袋想的，是从"AI 干活干到一半就断"这个日常问题里一条条逼出来的。

| # | 现实里的麻烦 | Skein 的做法 |
|---|---|---|
| 1 | 一个任务常常跑很久，中途会断（记性满、关机、换天） | 检查点文件，一个任务一份，每次覆盖成最新快照 |
| 2 | 换一个助手接手，不该从头再来 | 交接协议：谁交、谁接、接的人必须核对三样东西 |
| 3 | 一个项目里可能同时有两个助手干不同的活 | 各自一个工作目录、一个分支、一个任务号，任务带 300 秒租约 |
| 4 | 踩过的坑、定过的事，每次都重新讨论 | 知识库分四类存放，检索分六级，先便宜后贵 |
| 5 | 数据不能上传，必须全在本地 | 知识库是独立 git 仓，**故意不连远程** |
| 6 | 不搭服务器、不买服务、不写代码 | 纯文本 + 现成工具，零自研 |

还有三条设计约束，决定了它长成现在这样：

- **技能是注意力预算。** 每多挂一个技能，AI 每次开工就多读一段。所以并行技能只在并行期挂。
- **一处真相。** 任务状态只存在任务库里；检查点、文档、聊天记录都是副本，绝不复制状态。
- **出错要能查。** 所有写入带版本号（`checkpoint_rev`）和证据（文件:行号、提交号、命令输出），不写"应该没问题"。

更完整的设计推导（为什么是 4 个而不是 1 个或 5 个、哪些方案被否掉了）见 [`docs/design.md`](docs/design.md)。

---

## 3. 能做到什么，做不到什么

### 能做到

| 你会看到的现象 | 背后发生的事 |
|---|---|
| 第二天说"读检查点接着干"，它不重复昨天的活 | 检查点里有"已完成 / 下一步 / 不要重复"三节 |
| 新助手接手时先核对，而不是直接动手 | 核对任务归属、代码现状、检查点三样，对不上就停 |
| 叫另一个助手接手，不用等前任整理 | 接手方自己读任务和现场，拿到归属就能干；前任不需要先写总结或释放 |
| 它不会偷偷清理你没提交的改动 | 规定"检查点说干净也不许 `git clean`，先查来源" |
| 两个助手同时干，各自的分支不互相污染 | 独立工作目录 + 独立分支 + 独立任务号 |
| 问"以前是不是定过"能翻到原文 | 检索六级，命中就停，不整份加载 |
| 换电脑只改一个文件 | 所有路径集中在 `AGENTS.local.md` 的五个键里 |
| 私有资料不会跟着代码上 GitHub | 知识库在代码仓之外，单独一个仓、不连远程 |

### 做不到（先说清楚，避免误会）

- **它不会替你写代码。** 它约束的是 AI 的工作方式，不是内容。
- **它不替代 Git。** 版本管理还是 Git 的事。
- **它不是云服务，不跨机器同步。** 想同步得自己加远程仓——但那等于把私有资料传出去，不建议。
- **它不会自动解决"两个人都改了同一段"的语义冲突。** 同一文件不同段落 Git 能自动合，但合出来对不对，得有人复核。
- **它拦不住"旧助手还在写、新助手已经开始写"。** 任务归属能改派，但停不掉对方正在跑的命令。要让两个助手同时干活，得开独立工作目录；这是它管不了的地方。
- **不适合 5 分钟的小任务。** 写检查点比干活还贵，小任务直接干。

---

## 4. 安装

### 4.0 先看要准备什么

| 软件 | 干什么用 | 必须吗 | 装完必须做的额外设置 |
|---|---|---|---|
| AI 助手客户端<br>（Claude Code / Codex CLI / WorkBuddy 等） | 运行技能 | 必须 | 找到它的技能目录，见 4.1 的表 |
| Git for Windows | 提供 bash 环境 + 版本管理 | 必须 | 安装时选 "Git from the command line"；装完设置用户名邮箱 |
| Node.js 18 以上 | 装 Beads、QMD 用 | 用任务库就必须 | 装完 `node -v` 要能出版本号 |
| Beads（`@beads/bd`） | 任务状态与认领 | 强烈建议 | `bd metrics off` 关掉统计上报 |
| Everything + `es.exe` | 按文件名秒搜 | 可选 | **必须普通用户态运行并开启 IPC**，服务态会报 `Error 8` |
| QMD（`@tobilu/qmd`） | 换词、语义检索 | 可选（库超 50 篇再装） | 必须指定缓存与配置目录，见 4.4 |

**Windows 用户请注意：** 技能里的命令是 bash 语法，**请在 Git Bash 里跑**（开始菜单搜 "Git Bash"），不要在 `cmd` 或 PowerShell 里直接粘贴。PowerShell 处理中文路径容易乱码。

设用户名邮箱（只需一次）：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

### 4.1 档一：装技能（必做，约 3 分钟）

先确认你的客户端把技能放在哪：

| 客户端 | 技能目录 |
|---|---|
| Claude Code | `~/.claude/skills/` |
| Codex CLI | `~/.codex/skills/` |
| WorkBuddy | `~/.workbuddy/skills/` |
| 其他 | 查它的文档，找 `skills` 目录 |

**做法 A：用脚本（推荐）**

下载本仓库（右上角 Code → Download ZIP，解压），然后打开 Git Bash：

```bash
cd /d/下载/skein          # 换成你解压后的真实路径
bash install/install.sh --client all
```

macOS / Linux 用系统自带的"终端"，路径换成 `~/Downloads/skein`。

不想开 Git Bash 也可以用 PowerShell（同样的活）：

```powershell
cd D:\下载\skein
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

`-ExecutionPolicy Bypass` 只是让这一次运行放行，不改系统设置。

脚本只做一件事：把**全局技能**（只有 `task-checkpoint`）复制到上面那些目录；给了 `--project` 再把另外三个**项目级技能**复制到那个目录下的 `.claude/skills` 之类位置。**它不建库、不碰数据目录。** 已存在的不会覆盖，想覆盖加 `--force`（PowerShell 用 `-Force`）。

> 为什么分开：`task-checkpoint` 每个工作区都要用，装全局；另外三个只在特定工作区里才有意义，装全局会让不相干的项目也被它们触发，白占上下文。

**做法 C：你已经用 skills-manager 管技能**

那就不用跑上面的脚本，直接：

```bash
skills-manager projects deploy --agent codex "<工作区路径>" agent-handoff project-memory agent-collab
```

它建的是符号链接，改中心源即时生效。上面的 `install.sh` 会识别出符号链接并跳过，不会把链接拆成副本。

**做法 B：手动复制（不想跑脚本就这样）**

全局只放一个：

```
skills/task-checkpoint   →  ~/.claude/skills/task-checkpoint
```

另外三个放到**项目里**（把 `<项目>` 换成你的项目根目录，客户端换前缀）：

```
skills/agent-handoff     →  <项目>/.claude/skills/agent-handoff
skills/project-memory    →  <项目>/.claude/skills/project-memory
skills/agent-collab      →  <项目>/.claude/skills/agent-collab
```

放完把这三行写进 `<项目>/.git/info/exclude`，免得被提交进你自己的仓库：

```
/.claude/skills/agent-handoff/
/.claude/skills/project-memory/
/.claude/skills/agent-collab/
```

**层级别搞错：** `SKILL.md` 必须**直接**在技能文件夹里。变成 `skills/task-checkpoint/task-checkpoint/SKILL.md` 就读不到。

装完重启客户端。多数客户端只在启动时扫描一次技能目录。

**复制 vs 链接：** 脚本是复制，改本仓库的 `skills/` 不会自动同步。如果你想"改一处、各端立刻生效"，用 [skills-manager](https://github.com/xingkongliang/skills-manager) 部署——它建的是符号链接，`skills-manager projects deploy --agent codex <工作区> agent-handoff project-memory agent-collab` 这样按工作区挂载。

### 4.2 档二：装任务库 Beads（强烈建议）

```bash
npm install -g @beads/bd
bd version          # 应显示 1.3.x
bd metrics off      # 关掉统计，只在本机记录
```

**不要在这里 `bd init`。** 建库放在第 5 节，因为要和项目目录绑在一起。

### 4.3 档三之一：Everything（可选，按文件名搜索）

从 [voidtools.com](https://www.voidtools.com/) 装 Everything，把 `es.exe` 所在目录加进 PATH。

**必须做的设置：** 让 Everything 以**普通用户**身份运行（不要装成系统服务），并在选项里开启 **IPC**。否则 `es.exe` 会报 `Error 8: Everything IPC not found`。

**一个坑：** `es.exe` 直接输出是 GBK 编码，在 UTF-8 终端里看中文会乱码。技能里统一用 `-export-json` 导出再读，不要直接解析屏幕输出。

### 4.4 档三之二：QMD（可选，库大了才需要）

```bash
npm install -g @tobilu/qmd
qmd --version       # 应显示 2.9.x
```

**必须做的两件事：**

1. **指定目录**，否则缓存会写进系统盘：

```bash
export XDG_CACHE_HOME="$HOME/.cache"
export QMD_CONFIG_DIR="$HOME/.config/qmd"
```

2. **建集合时必须写白名单**，只列要索引的目录：

```bash
qmd collection add "<你的知识库路径>" --name skein-kb \
  --mask "INDEX.md,current.md,facts/*.md,decisions/*.md,runbooks/*.md"
```

这里故意只列五类：`journal/` 是流水账、`proposals/` 是没定稿的提案、`archive/` 是旧版本，索引进来只会让检索结果变脏。集合名 `skein-kb` 要和技能里的一致，改了名技能就找不到集合（那时会退回前三级检索，不会报错停住）。

三条铁律（都是踩过的）：

- 不要用 `**/*.md`，会把临时目录、隐藏目录一起吸进来
- 不要用 `{a,b}/**/*.md`，数量会对不上
- 改过 mask 要 `qmd collection remove` 重建，`qmd update` 不会清理失效条目

**什么时候值得开：** 知识库超过 50 篇或 1 MB，并且"看目录 + 搜关键词"已经找不到东西了。小库开了是净负担。

---

## 5. 建库：给一个工作区接上

### 5.1 什么叫"工作区"

**一个目录 = 一个工作区，里面可以放好几个 git 仓。**

```
H:/AI工作区/ChatGPT测试区/     ← 工作区根：放 AGENTS.local.md
├── wfa/                       ← 自己的 git 仓
├── 别的项目/                   ← 另一个 git 仓
└── 笔记/                       ← 不是 git 仓也行
```

库是**按工作区**建的，不是按仓建的。三个子项目共用一套任务库和知识库，任务标题带 `[子项目名]` 区分。

技能从当前目录**向上**找第一个 `AGENTS.local.md`，命中就停。所以子目录里不要再放第二份，会遮住工作区那份。

### 5.2 建库：跟 AI 说一句话

在工作区根目录打开你的 AI 客户端，说：

> **用 project-memory 给这个工作区建库，数据放 `D:/skein-data`**

它会读 `project-memory/references/init.md`，按顺序做：

1. 确认工作区根，扫一遍子目录有没有第二份 `AGENTS.local.md`（有就停下来问你）
2. 建 `<数据家>/<工作区名>/{store,checkpoints,kb,backups,worktrees}`
3. 写工作区根的 `AGENTS.local.md`（五个键）
4. 只在工作区根**本身是 git 仓**时，才把它加进 `info/exclude`
5. 建 `kb` 独立仓 + 首版 `INDEX.md` / `current.md` + 一次提交
6. 装了 `bd` 就顺手 `bd init`
7. 按验收表逐项核对

**不需要手工贴任何东西**，也没有第二个脚本要跑。

### 5.3 检查生成的路由

打开工作区根的 `AGENTS.local.md`，应该长这样：

| 键 | 填什么 | 说明 |
|---|---|---|
| `scope` | 工作区根绝对路径 | 就是放这个文件的目录 |
| `store` | 任务库路径 | 整个工作区共用 |
| `checkpoints` | 检查点目录 | 整个工作区共用 |
| `kb` | 知识库路径 | 整个工作区共用 |
| `worktree_root` | 并行工作目录的父目录 | 并行时才用 |
| `backups`（可选） | 备份目录 | 技能不强制要求 |

路径用**正斜杠** `/`，Windows 也写 `D:/skein-data/我的工作区`。

**这个文件是整套系统的总开关。** AI 找不到它，或者缺键，就会停下来报 `[HANDOFF_GAP]`，而不是瞎猜一个路径。这是故意的。

### 5.4 验收

| 检查 | 命令 | 期望结果 |
|---|---|---|
| 全局技能 | `ls ~/.claude/skills` | 看到 `task-checkpoint`（另外三个**不该**在这里） |
| 项目技能 | `ls <工作区>/.claude/skills` | 看到 `agent-handoff`、`project-memory`、`agent-collab` |
| 路由文件 | `cat <工作区>/AGENTS.local.md` | 五个键都有值 |
| 作用域唯一 | `find <工作区> -mindepth 2 -name AGENTS.local.md` | 无输出 |
| 忽略生效 | 工作区是仓根时 `git -C <工作区> check-ignore -v AGENTS.local.md` | 有一行输出 |
| 任务库能读 | `bd -C <store> list` | 不报错，可能为空 |
| 知识库无远程 | `git -C <kb> remote -v` | **没有任何输出** |
| 知识库已提交 | `git -C <kb> log --oneline` | 至少一条 |

再让 AI 试一句：**"读一下 AGENTS.local.md，告诉我 store 和 kb 分别在哪。"** 它能准确说出来，就说明路由通了。

---

## 6. 怎么使用

### 6.1 一天的样子

| 时刻 | 你做什么 | AI 做什么 |
|---|---|---|
| 早上开工 | 说"读一下 current.md 和检查点" | 先看现状，再问你要不要接着干 |
| 干活中 | 正常提要求 | 到阶段节点自己写检查点 |
| 要关机 | 说"记个检查点" | 写快照，包含下一步和别重复什么 |
| 换助手 | 说"让 B 接手这个任务"（先关掉 A） | B 自己核对现状、接管任务，不需要 A 先整理 |
| 要并行 | 说"两个人分开做" | 加载 `agent-collab`，各开一个工作目录 |

### 6.2 你只需要说这几句话

不用记命令，直接说人话：

| 你说 | 会发生什么 |
|---|---|
| "记个检查点" | 把当前进度、下一步、踩过的坑写成文件 |
| "读检查点接着干" | 先读，再动手，不重复已完成的部分 |
| "换个助手接手" | 新助手自己读任务、检查点和代码现场，接管后接着干；**不用前任先写总结或释放任务** |
| "以前是不是定过…" | 按索引 → 关键词 → 语义的顺序找原文 |
| "把这条结论记进知识库" | 写进 `facts/` 或 `decisions/` 并提交 |
| "把这件事拆成两个并行任务" | 建两个任务、两个工作目录，各认领一个 |
| "并行结束了" | 合并、清理工作目录、卸掉并行技能 |
| "这条别再做" | 写进检查点的"不要重复"一节 |

### 6.3 什么时候不该用

- **5 分钟能做完的事**——直接干，写检查点比干活贵
- **只有你一个助手、任务一口气能做完**——不需要交接
- **没有 git 的目录**——并线和检查点都依赖 git，先去 `git init`

---

## 7. 日常问题怎么解决

### AI 说"找不到技能"或完全没反应

1. 看目录层级：`~/.claude/skills/task-checkpoint/SKILL.md` 必须存在，不能多一层
2. 重启客户端（多数客户端启动时只扫一次）
3. 看技能文件开头有没有 `---` 包起来的 `name:` 和 `description:`，少了就不是合法技能

### 报 `[HANDOFF_GAP]`

意思是"缺少必要信息，我停下来不猜"。按顺序查：

1. 项目根有没有 `AGENTS.local.md`
2. 五个键是不是都在、有没有拼错（`checkpoints` 不是 `checkpoint`）
3. 路径是不是写成了反斜杠 `\`，改成 `/`
4. 路径指向的目录是不是真的存在

**这是保护机制，不是故障。** 让它猜路径，比停下来问你更危险。

### 两个助手抢同一个任务

任务有 300 秒租约。查归属：

```bash
bd -C "<store>" show "<任务号>"
```

- `assignee` 为空 → 直接认领
- 是别人、租约**没过期** → 停手，不许抢
- 是别人、租约**已过期** → 先 `reclaim` 回收，再认领

`reclaim` 会回收**所有**过期租约，不只你手上这个。回收完必须再 `show` 一次确认。

### 检查点越写越长

检查点是**快照**，不是日记。每次整份覆盖，只留最新状态。历史流水进 `journal/`。超过两屏就该删细节了。

### `bd` 报找不到数据库

用 `-C` 指定任务库路径，不要依赖当前目录：

```bash
bd -C "D:/skein-data/我的项目/store" list
```

不要设 `BEADS_DIR` 环境变量，多个项目会互相串。

### 中文乱码

- 优先用 Git Bash，别用 PowerShell
- `es.exe` 的输出必须走 `-export-json`，别读屏幕
- 文件统一存成 UTF-8（不带 BOM）

### 发现 `AGENTS.local.md` 出现在 git 里

说明忽略规则没生效。补一条：

```bash
echo "/AGENTS.local.md" >> .git/info/exclude
git rm --cached AGENTS.local.md
```

用 `.git/info/exclude` 而不是 `.gitignore`，是因为它只影响你这台机器，不会跟着仓库公开。

### 知识库被推到网上了

立刻检查：

```bash
git -C <kb> remote -v      # 必须为空
```

有远程就删掉：`git -C <kb> remote remove origin`。然后换掉里面出现过的敏感内容，别指望删 commit 能补救。

### `qmd` 搜不到东西

1. 集合建了吗：`qmd collection list`
2. mask 是不是白名单写法
3. 环境变量 `XDG_CACHE_HOME` / `QMD_CONFIG_DIR` 有没有带
4. 改过 mask 要 `remove` 重建，`update` 不清旧条目

### Everything 报 `Error 8`

它没在普通用户态跑，或者没开 IPC。改成用户态启动并开启 IPC。

### `worktree remove` 被拒绝

里面有没提交的改动。先看清楚是要保留还是丢弃，**不要加 `--force` 跳过判断**。

### 上下文被压缩后它开始重复劳动

压缩会留下"我记得做过"的错觉。让它**先重读检查点**再动手，特别是"已完成"和"不要重复"两节。

### 技能更新了但行为没变

- 如果你用 skills-manager 部署的：那是符号链接，改源文件即时生效，只需重启客户端
- 如果你是手动复制的：要重新复制一遍，复制不是链接

---

## 8. 文件都放在哪

```
skein/
├── README.md              你正在看的这份
├── docs/design.md         设计推导：为什么是四个技能、否掉了什么
├── skills/                四个技能本体
│   ├── task-checkpoint/   打结
│   ├── agent-handoff/     接续
│   ├── project-memory/    织存
│   └── agent-collab/      并线
├── templates/             模板：本机路由文件、全局规则
├── install/               技能安装脚本（两个平台各一版，只复制技能）
└── LICENSE
```

**技能是可拷的，数据不是。** `skills/` 可以随便复制给别的机器；`store`、`checkpoints`、`kb` 是你的私有数据，别提交到任何公开仓库。

---

## 9. 许可与依赖

MIT License，见 [LICENSE](LICENSE)。

用到的第三方工具，各自遵循它们自己的许可：

| 工具 | 用途 | 主页 |
|---|---|---|
| Beads | 任务状态 | [github.com/gastownhall/beads](https://github.com/gastownhall/beads) |
| QMD | markdown 检索 | [github.com/tobi/qmd](https://github.com/tobi/qmd) |
| Everything | 文件名搜索 | [voidtools.com](https://www.voidtools.com/) |
| Git | 版本管理 | [git-scm.com](https://git-scm.com/) |

Skein 本身不含任何自研的运行时，全部是 Markdown 规程 + 少量安装脚本。
