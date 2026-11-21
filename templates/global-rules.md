<!-- 用法：把下面各块贴进你的全局规则文件（例如 ~/.claude/CLAUDE.md、~/.codex/AGENTS.md、~/.workbuddy/AGENTS.md）。
     只想放项目里也完全可以——把同样内容放进项目根 AGENTS.md 即可，效果略弱但不会出错。 -->

## 任务生命周期与交接

- 上下文到 60%–75%、要停机换手、或即将被压缩时，先用 `task-checkpoint` 落盘再继续；中断后恢复先读检查点，不凭记忆续做。
- 换助手、冷启动接手用 `agent-handoff`；建库、检索、写回知识用 `project-memory`；只有多任务并行才用 `agent-collab`，并行结束即卸掉。
- 任务状态只认任务库（`bd`）；检查点、文档、聊天记录都是副本，不重复记状态。
- 同一任务同时只有一个写者。并行指多个任务，不是一个任务多人写。

## 私有路径

- 本机路径只从**工作区根**（从当前目录向上找到的第一个）`AGENTS.local.md` 读（`store` / `checkpoints` / `kb` / `worktree_root`）。
- 文件缺失或缺键就报 `[HANDOFF_GAP]` 并停下，禁止推测路径，禁止把绝对路径写进规则或技能正文。

## 记忆与证据

- 先读项目入口和知识库索引，引用已有条目时注明出处；缺项再查，别整份加载。
- 记忆和进度只用于定位。改代码、定计划、报状态前，核对实际文件、Git 状态和命令输出，纠正过时记录。
- 已知事实才有资格写进 `facts/`；推断和猜测写进 `proposals/`，标"未验证"。

## Windows 中文环境（非 Windows 可删）

- 优先 Bash；必须用 PowerShell 时，命令开头设置 UTF-8：
  `$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)`
- 文本存 UTF-8；含中文的 `.ps1` 用 UTF-8 带 BOM，`.bat/.cmd` 用 GBK。
- 中文路径加引号；复杂引号场景改用脚本文件传参，别在命令行里拼。
