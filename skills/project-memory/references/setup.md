# 新项目建库

**边界先划清**：`install` 脚本只建空骨架——目录、`AGENTS.local.md`、空的 `INDEX.md` / `current.md`、一次提交。**库的内容归 `project-memory`**，别的技能不写库。

## 顺序

**0. 先确认路由（跳过这步后面全会断）**

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL：先跑 install/install.sh --project \"$PROJ\""; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }
K="$(kv kb)"
[ -n "$K" ] || { echo "[HANDOFF_GAP] 缺 kb 键：先跑 install/install.sh --project \"$PROJ\""; exit 1; }
```

`$K` 就是知识库路径。**不要另起一个路径**——安装脚本已经把它写进 `kb` 键，两边不一致，检索和写回当场就断。

**1. 补齐目录并初始化独立仓**

```bash
mkdir -p "$K"/{facts,decisions,runbooks,journal,proposals,archive}
[ -e "$K/.git" ] || git -C "$K" init
git -C "$K" remote -v          # 必须无输出
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
git -C "$K" -c core.autocrlf=false add -A
git -C "$K" -c core.autocrlf=false -c user.name=agent -c user.email=agent@local commit -m "kb: 初始化"
```

安装脚本已经提交过一版空骨架，这一步是把它换成真实内容后的第二版。没有改动时 `commit` 会返回非零，那是正常的。

## 验收

| 项 | 标准 |
|---|---|
| 路由 | `AGENTS.local.md` 的 `kb` 指向 `$K`，且 `$K` 下确实是这个库 |
| remote | `git -C "$K" remote -v` 无输出 |
| 目录 | 六个目录都在 |
| INDEX | 能定位所有分类，不超 1000 tokens |
| current | 不含任务状态复制 |
| 提交 | `git -C "$K" log --oneline` 至少两条 |

## 常见错误

- **在代码仓里建 kb。** 代码仓可能有（将来设为）公开的 remote，等于把私有知识推出去。必须建在代码仓之外；具体位置由 `AGENTS.local.md` 的 `kb` 键决定，安装脚本会拒绝把数据家放在仓内
- **自己另定一个库路径。** 建得成，但 `search.md` / `curate.md` 都按 `kb` 键读，从此查不到
- **INDEX 写成读书笔记。** 它是目录，不是内容。内容进 `facts/`
- **初始化时 `git init` 在父目录。** 会连 store 一起纳管。每个库一个独立仓
