# 本机协作路由 · {{PROJECT}}

> 这个文件含本机绝对路径，**已被 `.git/info/exclude` 排除，永不提交**。
> 换电脑、换目录、换项目时，只改这里，不要改 `AGENTS.md`。
> 路径一律用正斜杠 `/`。

project: {{PROJECT}}
store: {{DATA}}/store
checkpoints: {{DATA}}/checkpoints
kb: {{DATA}}/kb
backups: {{DATA}}/backups
worktree_root: {{WORKTREE_ROOT}}

## 命令前缀

```bash
B="{{DATA}}/store"
KB="{{DATA}}/kb"
CKPT="{{DATA}}/checkpoints"

# 任务状态（不设 BEADS_DIR，避免多项目串库）
bd -C "$B" list
```

## 禁止

- 禁止把本文件提交或推送到任何远端
- 禁止把这些绝对路径写进 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md` 或技能正文
- 缺少本文件或缺键时，一律报 `[HANDOFF_GAP]` 后停下，不许推测路径
