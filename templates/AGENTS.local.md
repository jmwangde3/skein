# 本机协作路由 · {{SCOPE_NAME}}

> 这个文件含本机绝对路径，**不进版本控制，永不提交**。
> 换电脑、换目录、换工作区时，只改这里，不要改 `AGENTS.md`。
> 路径一律用正斜杠 `/`。

scope: {{SCOPE}}
store: {{DATA}}/store
checkpoints: {{DATA}}/checkpoints
kb: {{DATA}}/kb
backups: {{DATA}}/backups
worktree_root: {{WORKTREE_ROOT}}

## 这个文件管到哪

放在**工作区根**：从这里往下，所有子目录、所有 git 仓共用这一份。

```
{{SCOPE}}/                 ← AGENTS.local.md 在这
├── 项目A/                 ← 自己的 git 仓，共用这份路由
├── 项目B/                 ← 同上
└── 杂项/                  ← 不是 git 仓也行
```

技能从当前目录**向上**找第一个 `AGENTS.local.md`，命中这个文件就停。
所以**子目录里不要再放第二份**，否则会遮住这一份。

## 命令前缀

```bash
B="{{DATA}}/store"
KB="{{DATA}}/kb"
CKPT="{{DATA}}/checkpoints"

# 任务状态（不设 BEADS_DIR，避免多工作区串库）
bd -C "$B" list
```

多个子项目共用一个任务库时，任务标题以 `[子项目名]` 开头，别只靠记忆分辨。

## 禁止

- 禁止把本文件提交或推送到任何远端
- 禁止把这些绝对路径写进 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md` 或技能正文
- 缺少本文件或缺键时，一律报 `[HANDOFF_GAP]` 后停下，不许推测路径
