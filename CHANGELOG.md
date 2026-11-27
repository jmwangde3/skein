# Changelog

## v2.0.1 (2026-11-27 · 基于 Windows 本地实测与复测修复)

- **修复 E5 后台写入检测（Windows Git Bash 漏检）**：`bin/skein-cli` 的 `check_bg_writers` 升级为三层探测（`.git/index.lock` + 进程命令行 + 工作树 10 秒内文件 mtime 活跃写入兜底），跨平台覆盖无路径参数的后台重定向写入。
- **新增 TRAE CN 适配**：`skein-cli init --trae` 自动生成 `.trae/rules/project_rules.md`；`install/install.ps1` 自动生成纯 ASCII + CRLF 的 `~/.local/bin/skein-cli.cmd` shim，彻底解决 Windows `cmd.exe` 按 GBK 解析 UTF-8 路径乱码问题。
- **新增 QoderCN 适配**：`install/install.ps1` 增加 `qoder-cn`（`~/.qoder-cn/skills`）目标；实测确认 QoderCN 的 `ai-memory` hook 合并至 `~/.qoder-cn/settings.json` 即可正常捕获。
- **Codex Hook 排障结论定型**：Native Windows 下 Codex 无需转 WSL2，首次安装或修改 `~/.codex/hooks.json` 后进入交互式 `codex` 执行一次 `/hooks` 信任 8 条 hook 即可正常捕获。

## v2.0.0 (2026-11-27)

- 新增 `bin/skein-cli` 单命令外部封装层，落实工具代劳原则。
- 原 4 Skill 拆分为 5 个严格解耦的极薄 Skill（`skein-init`、`task-checkpoint`、`agent-handoff`、`kb-retrieval`、`agent-collab`）。
- `agent-handoff` 改为项目级常驻可发现，支持 A 零准备 + 用户在 B 说一句“继续”直恢，内置 6 项可验收清单。
- `agent-collab` 补齐“模式 A：独立并行 worktree”与“模式 B：同任务单写者 + 只读观察者”。
- 解除 Dolt 版 Beads 强依赖，改用单二进制 `kanban-md` + `ai-memory`（含 `cass` 兜底口）；清除全部个人硬编码路径与过时规则。
