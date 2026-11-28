# Changelog

## v2.0.6 (2026-11-28 · 接手简报精炼 + mark 语义保留 + 短任务免维护)

- 重复 `mark` 保留语义记录，linked worktree 单独绑定任务并复用原项目档案。默认接手简报展示最新目标，可用 `resume --full` 展开。
- 接手检查使用当前工作树的真实索引锁和短间隔变化证据，取消整树 mtime 扫描。统一短任务免维护规则。
- 修正知识库提交范围、并行认领示例、Windows 强制升级和仓外冒烟测试目录。

## v2.0.5 (2026-11-28 · 隔离「接手」与「继续」触发词 + 修复悬空引用)

- **词面隔离接手触发词**：将 `agent-handoff` 触发词从「继续」改为「接手」，彻底避免同会话断流/暂停后说「继续」误触发 `skein-cli resume`（同步更新 `SKILL.md`、`bin/skein-cli`、`docs/requirements.md`、`docs/design.md`、`README.md`）。
- **修复悬空文件引用**：移除 `skills/kb-retrieval/SKILL.md` 中对不存在的 `references/curate.md` 的引用（整理阈值已在 `references/search.md` 内），并在 `tests/smoke-test.sh` 新增第 13 项引用完整性自动校验。

## v2.0.4 (2026-11-28 · 修复 v2.0.3 验收新增问题 4 & 5)

- **修复问题 4（新项目 `ai-memory recent` 404 误报 FAIL）**：`skein-cli check`（含 `--strict`）与 `resume` 识别 `404 Not Found` / `not found in workspace`，将其作为新项目正常 `[INFO]` 放行；仅对真正服务故障报 `[FAIL]` / `[WARN_EXTERNAL_CAPTURE]`，且精准提取真实 `Error:` 行而非 `INFO starting` 横幅。
- **修复问题 5（`init --adopt-existing` 静默覆盖 `AGENTS.md` 规则块）**：`skein-cli init` 遇到已存在 `<!-- skein-rules -->` 块时默认**原样保留并提示**；仅在显式传 `--update-rules` 时替换，且修改已有 `AGENTS.md` 前一律自动备份至 `<data_dir>/backups/AGENTS.md.<时间戳>.bak` 并打印备份路径。

## v2.0.3 (2026-11-28 · 修复接手问题单全部 3 项问题)

- **修复问题 1（`ai-memory` 参数错误与静默吞错）**：`bin/skein-cli` 的 `resume` 改为在项目目录执行经核验的 `ai-memory recent`（移除不存在的 `status --project`）；不再用 `2>/dev/null` 掩盖错误，命令失败时明确输出 `[WARN_EXTERNAL_CAPTURE]` 与真实退出码/报错。
- **修复问题 2（v1 老库迁移/补档）**：`skein-cli init` 新增 `--adopt-existing` 参数，可在不移动、不覆盖旧数据的前提下就地补齐 `.skein-scope`、`board/`、`checkpoints/done/`、`kb/facts/projects/` 与 `INDEX.md`，并在 `skein-init` 与 `README.md` 补全老库迁移补档步骤。
- **修复问题 3（`check` 与冒烟测试覆盖接手包完整性）**：`skein-cli check` 新增 `.skein-scope`、当前子项目最小档案（`READY` 状态）及 `ai-memory recent` 连通性体检，并新增 `--strict` 模式将缺档等 `[WARN]` 升级为失败；`tests/smoke-test.sh` 扩展至 12 项，覆盖老库收编、`check --strict` 与 `ai-memory` 正常/失败显错回归。

## v2.0.2 (2026-11-27 · 修复 PowerShell 5.1 编码与未装客户端目录污染)

- `install/install.ps1` 改为 UTF-8 带 BOM + CRLF，新增 BOM 回归校验。
- `all` 模式仅安装到本机已存在配置目录的客户端，新增 `-CliOnly` / `--cli-only`。

## v2.0.1 (2026-11-27 · 基于 Windows 本地实测与复测修复)

- 修复 E5 后台写入检测（新增工作树 10 秒内文件 mtime 活跃写入兜底）。
- 新增 TRAE CN 适配（`--trae` 生成 `.trae/rules/project_rules.md` + 纯 ASCII CRLF `skein-cli.cmd` shim）与 QoderCN 安装目标。

## v2.0.0 (2026-11-27)

- 新增 `bin/skein-cli` 单命令外部封装层，原 4 Skill 拆分为 5 个严格解耦的极薄 Skill。
