# Skein v2 · 一绞线

> **给 AI 助手用的工作规程 + 轻量小工具：记进度、换人接手、查资料、双人协作不打架。**
> 你不需要懂底层架构。会打开终端复制粘贴、会看文件夹，就能用。

Skein（读作"斯肯"）在英文里是"一绞线"的意思。你让 AI 干一个任务，就像理一绞线：干到一半打个结记住做到哪，换另一个 AI 助手时直接接上，两个助手同时干活时各走各的线不缠在一起。

---

## 1. 这是什么？解决什么痛点？

用 AI 助手（Codex、WorkBuddy、QoderCN、TRAE、Claude Code 等）干稍大一点的活，几乎人人都会遇到这 4 个头疼事：

- **干到一半断了**：窗口关了、限流了、明天继续，AI 忘了昨天做到哪、试过什么错路，从头再来一遍。
- **想换另一个 AI 接手**：A 写了一半卡住了，想换 B 来接着干，结果要把背景、改过的文件、排除的方案重新讲 10 分钟。
- **项目资料太多**：文档、历史决策越攒越多，全丢给 AI 太费 token，不给它又反复犯老错。
- **想让两个 AI 同时干活**：两个人改同一个文件夹，互相把对方的代码覆盖掉。

现实里怎么解决这些事？很简单：**交接班小纸条 + 项目档案卡 + 档案柜 + 排班表。**

Skein v2 就是把这四样东西做成了 **1 个极轻的本地命令行小工具（`skein-cli`）+ 5 份写给 AI 看的短规程（Skill）**。机械记账、查 Git、查后台进程全交给工具自动跑，**不让 AI 浪费时间和 token 写长篇日记**；数据全部留在你自己的电脑里，纯本地离线。

### 5 个技能，各管一件事（互不重叠）

每个技能挂着都会占 AI 的一点注意力，所以 Skein v2 故意拆成 5 个小块，**用谁开谁，用完就关**：

| 技能名 | 用一句人话说 | 什么时候开 | 平时占 token 吗 |
|---|---|---|---|
| `skein-init` | 给新项目建库、写项目档案卡 | 只在**第一次建库**或新增子项目时开，建完就关 | 关掉后 **0** |
| `task-checkpoint` | 干活前留一张 3 行小纸条，踩坑/定方案补 1 行 | **全局常驻**（唯一一直开着的） | 极少（正文不到 40 行） |
| `agent-handoff` | 换人接手或新开窗口时，一键拉齐现场 | 放项目里常驻可发现，你在新助手里只说“继续”就会自动触发 | 未触发约 **50 tokens** |
| `kb-retrieval` | 从大档案柜里只抽需要的那一页 | **只有大型复杂项目才开**，小项目完全不用挂 | 小项目 **0** |
| `agent-collab` | 两个助手同时干活，怎么隔离不打架 | **只有真的双人协作时才开**，干完合并就关 | 非协作期 **0** |

---

## 2. 能做到什么，做不到什么

### 能做到

- **A 不用提前整理，B 说一句“继续”就能接手**：A 干到一半停写（就算窗口还开着）或突然限流，打开 B 只说“继续”，B 跑一条 `skein-cli resume` 就能拿齐 6 样东西：最后确认的目标、变更过的约束、关键决定及理由、已经排除的方案、待验证假设、下一步。
- **新助手冷启动不乱翻代码**：每个活跃子项目有一份不超过 2 KB 的“项目档案卡”（干什么、从哪进、怎么跑），新助手只读当前这一份，不会把整个目录通读一遍。
- **防误覆盖**：如果 A 还有后台命令正在往目录里写文件，B 接手前会自动报警停手，先问你“等它跑完还是停掉”。
- **双人协作分清两种模式**：各自改不同模块时自动开独立目录和分支（`git worktree`）；一个人写、另一个人实时审查/跑测试时走“单写者 + 只读观察者”。
- **纯本地离线、低 CPU**：所有私有记录和知识库放在代码仓之外的独立本地文件夹，不传云端。

### 做不到（先说清楚，避免误会）

- **不适合 5 分钟能做完的小事**：改一行错别字直接让 AI 改就行，没必要留锚点。
- **不跨电脑自动云同步**：设计目标就是单机纯离线、数据不上传。
- **不能自动解决“两人改同一行代码”的冲突**：Git 遇到同段冲突仍需要你人工确认保留哪边。
- **不替代 Git**：版本回滚和分支管理依然靠 Git（文档/调研类项目也可以 1 秒 `git init` 纳入管理）。

---

## 3. 安装准备（分 3 档，按需装）

### 档一：必装（约 3 分钟）

1. **安装 Git**：Windows 装 [Git for Windows](https://git-scm.com/download/win)（提供 Git Bash），macOS/Linux 自带。
2. **安装 `skein-cli` 和技能**：
   - **如果你用 [skills-manager](https://github.com/xingkongliang/skills-manager) 管技能（强烈推荐）**：
     把本仓库里的 `skills/` 放进你的 `skills-manager` 中心源，按第 1 节的表按需开关；然后只跑安装脚本的“仅装命令行工具”模式：
     - Windows PowerShell：
       ```powershell
       powershell -ExecutionPolicy Bypass -File install\install.ps1 -CliOnly
       ```
     - macOS / Linux / Git Bash：
       ```bash
       bash install/install.sh --cli-only
       ```
   - **如果你不用 `skills-manager`**：
     去掉 `-CliOnly` / `--cli-only` 直接跑上面的命令。脚本只会给**你电脑上已经装了的客户端**复制全局技能，不会乱建你没装的客户端目录。
3. **把命令行工具加入 `PATH`**（让终端和 TRAE 能直接敲 `skein-cli`）：
   - Windows：把 `%USERPROFILE%\.local\bin` 加入用户环境变量 `PATH`（脚本已自动生成兼容中文路径的 `skein-cli.cmd`）。
   - macOS / Linux：确保 `~/.local/bin` 在 `PATH` 中。

### 档二：强烈推荐（让“突然断掉也能接上”更稳）

- **[ai-memory](https://github.com/akitaonrails/ai-memory)**（Rust 单文件本地离线服务，默认不调外部 LLM、空闲 CPU 为 0%）：
  它通过客户端 Hook 在后台静默记下你和 AI 刚聊过的排错过程，哪怕 A 还没来得及记小纸条就崩了，B 接手时 `skein-cli resume` 也能顺带拉出近期会话记录。
  - **Codex 注意**：装完后进入交互式 `codex`，输入 `/hooks` 信任一次 `ai-memory` 的 8 条 hook 才会开始捕获。
  - **QoderCN 注意**：国内版 QoderCN 读的是 `~/.qoder-cn/settings.json`（不是国际版 `~/.qoder/settings.json`），把 hook 配置合并进 `~/.qoder-cn/settings.json` 即可正常捕获。
  - **TRAE CN 注意**：TRAE 不支持 CLI Hook，靠项目里的 `.trae/rules/project_rules.md` + `skein-cli` 正常读写同一套任务锚点与档案。

### 档三：按需选装（用不到就别装）

- **[kanban-md](https://github.com/antopolskiy/kanban-md)**：只有需要**两个 AI 并行认领任务**时才装，单文件纯 Markdown 看板，输出极省 token。
- **[qmd](https://github.com/tobi/qmd)**：只有单个项目的知识库文档**超过 50 篇**、关键词搜不到时才装，做本地离线语义检索。

---

## 4. 给项目建库（每个工作区只做一次）

### 情况 A：新项目 / 新工作区

1. 用 `skills-manager` 临时打开 `skein-init`（建完就关）。
2. 在工作区根目录跑建库命令（数据家建议放在代码仓外面的独立目录，比如 `D:/skein-data`）：
   ```bash
   # 普通代码项目
   skein-cli init --workspace "D:/work/我的项目" --data "D:/skein-data"

   # 如果是纯文档/调研目录（还没有 Git），加上 --git-init
   skein-cli init --workspace "D:/work/我的调研" --data "D:/skein-data" --git-init

   # 如果会用 TRAE CN 打开，加上 --trae 自动生成 .trae/rules/project_rules.md
   skein-cli init --workspace "D:/work/我的项目" --data "D:/skein-data" --trae
   ```
3. 让 AI 读建库索引，给**你确认纳入范围的活跃子项目**各写一份 ≤2 KB 的最小项目档案。
4. 跑验收体检：
   ```bash
   skein-cli check --strict
   ```
   全绿后，用 `skills-manager` **卸载 `skein-init`**。

### 情况 B：已有 v1 老库升级到 v2

老库已有数据目录、不想搬文件，只需加 `--adopt-existing` 就地收编：

```bash
skein-cli init --workspace "D:/work/老项目" --data "D:/skein-data" --adopt-existing
```

- 会完整保留你原有的知识库、检查点和 `AGENTS.md` 里的自定义规则（不会静默覆盖；只有显式加 `--update-rules` 才会更新规则块，且改前自动备份到 `backups/`）。
- 收编后用 `skein-init` 给活跃子仓补写一份 ≤2 KB 的最小档案，再跑 `skein-cli check --strict` 验收即可。

---

## 5. 日常怎么用？（你只需要说这几句话）

装好建完库之后，你平时**不用记命令**，直接跟 AI 说人话就行：

| 场景 | 你对 AI 说什么 | 背后会自动发生什么 |
|---|---|---|
| 日常干活 | 正常提需求 | AI 动第一笔代码前跑 1 条 `skein-cli mark` 留 3 行小纸条；推翻方案或排除死路时补 1 行 `note`，不写长篇日记 |
| 换个 AI 接着干 | 打开另一个 AI，只说一句：**“继续”** | B 跑 1 条 `skein-cli resume`，拉齐档案卡 + Git 现场 + 小纸条 + 近期会话；只有 1 个未完任务直接开干，多个先列清单问你 |
| 原 AI 返场（A→B→A） | 回到 A，说：**“继续”** | A 同样重跑 `skein-cli resume`，不凭旧记忆盲做 |
| 查大项目历史资料 | 先打开 `kb-retrieval`，问：**“以前为什么定这个方案？”** | 按 索引 → 关键词 → `ai-memory` → `qmd` 顺序抽页，命中即停 |
| 两个 AI 同时干活 | 先打开 `agent-collab`，说：**“分成两个并行任务”** 或 **“你只读审查，A 负责改代码”** | 独立并行自动开独立目录/分支；实时配合锁定单写者 + 只读观察者；干完合并后提醒你关掉 `agent-collab` |
| 阶段结束 | 说：**“先到这，收尾”** 或 **“任务做完了，关掉”** | 更新下一步或跑 `skein-cli close` 归档任务 |

### 一天的真实样子

- **上午（在 WorkBuddy 干活）**：直接提需求，AI 改代码前自己留最小锚点，排除一个错误方案时顺手记 1 行。
- **中午（额度满了或想换工具）**：不用让 WorkBuddy 写总结，直接停写（窗口开着都行）。
- **下午（打开 Codex / QoderCN / TRAE）**：只发两个字 **“继续”**，新助手 10 秒内复述出目标、约束、排除项和下一步，直接接着改。
- **傍晚（需要双人冲刺）**：在 `skills-manager` 里打开 `agent-collab`，让两个助手在各自 worktree 分头写两个模块，合完测试通过后关掉 `agent-collab`。

---

## 6. 常见问题怎么解决

### Codex 装了 `ai-memory` 却不捕获？
Codex 默认跳过未信任的非托管 hook。在已信任的项目目录打开交互式 `codex`，输入 `/hooks`，确认信任 `ai-memory` 的 8 条 hook 即可（每次改写 `hooks.json` 后需重新信任一次）。

### QoderCN 不捕获？
`ai-memory` 默认写的是国际版目录 `~/.qoder/settings.json`，而国内版 QoderCN 读的是 `~/.qoder-cn/settings.json`。把 hook 配置合并到 `~/.qoder-cn/settings.json` 即可。

### TRAE 终端提示找不到 `skein-cli`？
确认已运行 `install\install.ps1 -CliOnly`（会在 `%USERPROFILE%\.local\bin` 生成纯 ASCII 的 `skein-cli.cmd`），并把 `%USERPROFILE%\.local\bin` 加入系统用户 `PATH`，然后重启 TRAE。

### AI 报 `[HANDOFF_GAP]` 停下来了？
这是保护机制，不是崩了——意思是缺少必要路径或现场对不上，AI 拒绝瞎猜。跑一下 `skein-cli check` 就能看到具体缺哪一项。

### 接手时看到 `[WARN_BG_ACTIVE]`？
说明检测到当前目录存在 `.git/index.lock`、相关后台进程，或者最近 10 秒内刚有文件被改动。先确认是不是前一个助手还有命令没跑完，决定等它跑完或终止后再让新助手写。

### 新项目跑 `skein-cli check --strict` 会因为 `ai-memory` 没记录报错吗？
不会。v2.0.4 已把新项目 `ai-memory` 返回 404 识别为正常的 `[INFO]`（尚未产生首次捕获记录），只有服务真正挂掉才会报 `[FAIL]`。

---

## 7. 文件都在哪 & 许可

```
skein/
├── bin/skein-cli          单命令本地小工具（把多步机械操作压成 1 条命令）
├── skills/                5 份短规程（skein-init / task-checkpoint / agent-handoff / kb-retrieval / agent-collab）
├── install/               Windows（PowerShell）与 macOS/Linux（Bash）安装脚本
├── templates/             全局规则模板（贴进客户端全局规则用）
├── docs/                  requirements.md（纯净需求稿）与 design.md（设计推导）
├── tests/smoke-test.sh    12 项自动化冒烟测试（bash tests/smoke-test.sh）
└── LICENSE                MIT License
```

快速自检：`bash tests/smoke-test.sh`，看到 `全部 12 项冒烟测试通过！` 即表示本机脚本运行完全正常。
