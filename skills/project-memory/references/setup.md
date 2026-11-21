# 新项目建库

## 顺序

**1. 建目录并初始化独立仓**

```bash
S="${S:?先设 S=<私有根>/<项目>，私有根在代码仓之外}"
mkdir -p "$S/kb"/{facts,decisions,runbooks,journal,proposals,archive}
git -C "$S/kb" init
git -C "$S/kb" remote -v          # 必须无输出
```

**2. 写 `INDEX.md`**

必须有的三块：

- 一句话说明这个库管什么、不管什么（不管的去哪）
- 分类表：每个目录放什么、什么时候看
- 常查表：常见问题 → 看哪个文件

控制在 **1000 tokens 以内**。超了就是导航变内容，整理时会变成负担。

**3. 写 `current.md`**

当前阶段、在做什么、下一步。**不要复制任务状态**——那是 Beads 的活。可以写「任务状态看 `bd -C <store> list`」。

**4. 首次提交**

```bash
cd "$S/kb" && git add -A
git -c user.name=agent -c user.email=agent@local commit -m "kb: 初始化"
```

## 验收

| 项 | 标准 |
|---|---|
| remote | `git remote -v` 无输出 |
| 目录 | 六个目录都在 |
| INDEX | 能定位所有分类，不超 1000 tokens |
| current | 不含任务状态复制 |
| 提交 | `git log` 有一条 |

## 常见错误

- **在代码仓里建 kb。** 代码仓可能有（将来设为）公开的 remote，等于把私有知识推出去。必须建在代码仓之外（例如数据家目录 `~/skein-data/<项目>/kb`），具体路径见项目 `AGENTS.local.md` 的 `kb` 键
- **INDEX 写成读书笔记。** 它是目录，不是内容。内容进 `facts/`
- **初始化时 `git init` 在父目录。** 会连 store 一起纳管。每个库一个独立仓
