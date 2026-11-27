# Changelog

## v2.0.2 (2026-11-27 · 修复 PowerShell 5.1 编码与未装客户端目录污染)

- **修复 `install/install.ps1` 编码**：改为 **UTF-8 带 BOM + CRLF**，彻底解决 Windows PowerShell 5.1 按 GBK 解析中文导致语法报错的问题，并在 `tests/smoke-test.sh` 加入 BOM 自动回归校验。
- **修复 `-Client all` / `--client all` 污染未安装客户端目录**：`all` 模式改为**仅安装到本机已存在配置目录的客户端**，跳过未安装的客户端（显式指定单个客户端名时才会新建目录）。
- **新增 `-CliOnly` / `--cli-only` 开关**：方便 `skills-manager` 用户只安装/更新 `skein-cli` 与 `skein-cli.cmd`，完全不触碰任何技能目录。

## v2.0.1 (2026-11-27 · 基于 Windows 本地实测与复测修复)

- **修复 E5 后台写入检测（Windows Git Bash 漏检）**：`bin/skein-cli` 的 `check_bg_writers` 升级为三层探测（`.git/index.lock` + 进程命令行 + 工作树 10 秒内文件 mtime 活跃写入兜底）。
- **新增 TRAE CN 适配**：`skein-cli init --trae` 自动生成 `.trae/rules/project_rules.md`；`install/install.ps1` 自动生成纯 ASCII + CRLF 的 `~/.local/bin/skein-cli.cmd` shim。
- **新增 QoderCN 适配**：`install/install.ps1` 增加 `qoder-cn`（`~/.qoder-cn/skills`）目标。

## v2.0.0 (2026-11-27)

- 新增 `bin/skein-cli` 单命令外部封装层，原 4 Skill 拆分为 5 个严格解耦的极薄 Skill。
- `agent-handoff` 改为项目级常驻可发现，内置 6 项可验收清单；`agent-collab` 支持双模式协作。
- 解除 Dolt 版 Beads 强依赖，清除全部个人硬编码路径与过时规则。
