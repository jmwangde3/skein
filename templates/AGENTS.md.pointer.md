<!-- 用法：把下面「Skein 协作」这一节整体复制到项目根目录的 AGENTS.md / CLAUDE.md / GEMINI.md。不要复制本行注释。 -->

## Skein 协作

- 本机路径只从 `AGENTS.local.md` 读五个键（project / store / checkpoints / kb / worktree_root）。缺文件或缺键就报 `[HANDOFF_GAP]` 并停下，禁止推测路径。
- 长任务用 `task-checkpoint` 落盘；换助手用 `agent-handoff`；建库、检索、写回用 `project-memory`；只有并行才挂 `agent-collab`，并行结束就卸。
- 任务状态只信 `bd -C <store> ...`。检查点、文档、聊天记录都是副本，不重复记状态。
- 知识库同一时刻只有一个写者，其他人把结论写进 `proposals/`。
