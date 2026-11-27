# Skein v2 · 一绞线

> **外部工具干脏活，五份极薄规程控边界。**
> 让多 AI 助手实现单机离线下的日常轻量记录、A 零准备跨端接手、冷启动上手、大知识库按需抽页与双人安全协作。

## 为什么升级到 v2

v1 靠纯 Prompt 让 Agent 自己跑多步 bash 核对、手写 10 节检查点并维护 Dolt 版 Beads 租约，日常耗时且容易漏写。v2 遵循**工具代劳原则**：

- **自动静默留痕**：由 [ai-memory](https://github.com/akitaonrails/ai-memory)（Rust 单二进制，默认 0 LLM，原生 Hook 覆盖 Claude Code / Codex / Antigravity / WorkBuddy）在后台静默捕获会话，日常 0 Agent token；提供 Hook + [cass](https://github.com/Dicklesworthstone/coding_agent_session_search) 零后台备选方案。
- **单命令封装**：`bin/skein-cli` 把建库、写前留痕、一键接手汇总、后台进程探测与 worktree 启停压成单条命令。
- **轻量化任务锁**：用纯 Markdown 单二进制 [kanban-md](https://github.com/antopolskiy/kanban-md) 替代已迁移到 Dolt 的原版 Beads，且仅在并行期启用。
- **5-Skill 严格解耦**：把原 `project-memory` 拆为一次性 `skein-init` 与大库专用 `kb-retrieval`，小项目日常零大知识库租金。

## 5 个 Skill 分工与挂载策略

通过 [skills-manager](https://github.com/xingkongliang/skills-manager) 人工按需开关：

| Skill | 挂载位置与时机 | 唯一职责 |
|---|---|---|
| `skein-init` | 一次性挂载，建完即卸 | 建库、建目录骨架、为纳入范围的活跃子项目写 ≤2KB 最小档案 |
| `task-checkpoint` | 全局常驻（极薄） | 写前 1 条 `skein-cli mark` 留痕 + 语义拐点 1 行 `note` |
| `agent-handoff` | 项目级常驻可发现（未触发约 50 tokens） | 兑现“A 零准备 + 用户在 B 说一句‘继续’直恢”，含 6 项验收清单与后台命令占用检测 |
| `kb-retrieval` | 仅大型/复杂项目启用，小项目不挂 | 按需抽页（索引 → `rg` → `ai-memory` → 超 50 篇开 [qmd](https://github.com/tobi/qmd)）与离线写回 |
| `agent-collab` | 仅双 Agent 协作期启用，结束即卸 | 模式 A（`worktree` + `kanban-md` 独立并行）与模式 B（单写者 + 只读观察者实时配合） |

## 快速开始

### 1. 安装技能与 `skein-cli`

macOS / Linux / Windows Git Bash：

```bash
bash install/install.sh --client all
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Client all
```

若使用 `skills-manager` 统一管理，直接将本仓库 `skills/` 纳入中心源并按上表策略部署符号链接，再把 `bin/skein-cli` 加入 `PATH`（或软链至 `~/.local/bin/skein-cli`）。

### 2. 推荐外部工具（单机本地离线）

| 工具 | 作用 | 必需度 |
|---|---|---|
| `git` | 统一版本与现场核对底座（含文档任务） | 必需 |
| [ai-memory](https://github.com/akitaonrails/ai-memory) | 静默 Hook 捕获与跨端零准备 handoff（默认 0 LLM） | 强烈建议（Windows 原生为 Experimental，可改走 WSL2 或 `cass` 兜底） |
| [kanban-md](https://github.com/antopolskiy/kanban-md) | 并行期轻量任务认领与 TUI（`--compact` 省 token） | 并行时建议 |
| [qmd](https://github.com/tobi/qmd) | 超 50 篇大知识库本地混合检索 | 大库按需 |

### 3. 建库与运行自带冒烟测试

```bash
# 运行自动化冒烟测试
bash tests/smoke-test.sh

# 在目标工作区建库（文档类非 Git 目录可加 --git-init）
skein-cli init --workspace "/path/to/workspace" --data "$HOME/skein-data"
```

## 目录结构

```
skein/
├── bin/skein-cli          单命令外部封装层（init/mark/note/resume/wt-add/wt-clean/check）
├── skills/                5 个严格解耦的极薄 Skill
│   ├── skein-init/
│   ├── task-checkpoint/
│   ├── agent-handoff/
│   ├── kb-retrieval/
│   └── agent-collab/
├── docs/
│   ├── requirements.md    纯净版需求规格说明书（v2.2）
│   └── design.md          v2 架构设计与边界推导
├── install/               跨平台安装脚本（Bash + PowerShell）
├── templates/             无硬编码的全局规则模板
└── tests/smoke-test.sh    skein-cli 自动化冒烟测试
```

## 许可

MIT License，见 [LICENSE](LICENSE)。
