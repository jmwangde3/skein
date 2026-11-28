# 接手异常恢复速查表（agent-handoff）

| 现场特征 | 动作 | 禁止 |
|---|---|---|
| 当前工作树出现 `[WARN_BG_ACTIVE]` 或已知后台命令可能仍在写 | 核查真实锁、进程和产物，存在持续冲突时再问用户等待还是终止 | 擅自删锁或覆盖写入 |
| `TASK_ANCHOR: MULTIPLE` | 列出全部未完任务 ID 与目标，让用户选择 | 自行猜测或合并任务 |
| `TASK_ANCHOR: NONE` 但工作树有未提交改动 | 结合 `git diff` + `ai-memory`（或 `cass`）摘要重建 6 项清单，不确定处先问用户 | 执行 `git clean` 或 `git checkout -- .` |
| `PROJECT_BRIEF: MISSING` | 只对当前子仓做最小摸底（README + 入口 2 层），不开全仓通读 | 读取其他无关子仓档案 |
| 档案与 Git 现场矛盾 | 以 Git 现场和实际文件为准，必要时更新档案并 commit | 按过时档案强改代码 |
| 缺 `AGENTS.local.md` 或关键路由键 | 停手报 `[HANDOFF_GAP]`，请用户确认是否已建库 | 猜测路径写入 |
