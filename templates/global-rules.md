<!-- 用法：贴入你的各客户端全局规则文件（如 ~/.claude/CLAUDE.md、~/.codex/AGENTS.md、~/.workbuddy/AGENTS.md 等）。
     不包含任何本机绝对路径，换机器无需修改。 -->

## Skein v2 全局协同原则

- 机械采集与现场核对优先走外部工具（`skein-cli` / `ai-memory` / `kanban-md`），不手写长篇检查点，不浪费日常轮次。
- 写前留痕：在已建 Skein 库的工作区中，一次可完成、易于重做且没有待交接决定的小改动，可直接处理，零次 Skein 专用调用。其余可能留下半成品的任务，首次实质修改或启动长耗时操作前，按 `task-checkpoint` 执行 `skein-cli mark`；仅在目标/约束变更、关键决策或排除方案时追加 1 行 `skein-cli note`。
- 接手与返场：换助手、新会话或返场继续时，按 `agent-handoff` 执行 `skein-cli resume`，严禁凭旧对话记忆盲做。
- 按需开关：建库（`skein-init`）、大知识库（`kb-retrieval`）、双人协作（`agent-collab`）由用户通过 `skills-manager` 手动开关，完成阶段后主动提醒卸载。
- 路径隔离：所有本机路径只从工作区根 `AGENTS.local.md` 读取；缺失或缺键立即停手报 `[HANDOFF_GAP]`，禁止猜测路径。
- 证据优先：记忆与档案仅作导航，改代码或下结论前以 Git 现场和实际文件为准；未核实的内容明确标注「未核实」。
