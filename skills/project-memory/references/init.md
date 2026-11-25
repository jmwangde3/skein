# 接入一个工作区并建库

这是**唯一**的建库入口。具体动作由技能目录里的 `scripts/init.sh` 完成——脚本跟着技能一起部署，不依赖机器上有没有 Skein 源码仓。

## 两种用法，结果不同

**用技能（完整建库）**：在工作区根对 AI 说「用 project-memory 给这个工作区建库，数据放 `D:/skein-data`，我要接手 `<仓名>`」。AI 读本文件，先跑脚本，再按「逐仓建档」给**目标仓**写成一份档案。

**自己跑脚本（只有骨架）**：在终端里执行同一条命令，技能目录换成你客户端的真实位置：

```bash
bash ~/.claude/skills/project-memory/scripts/init.sh \
  --workspace "D:/work/我的工作区" \
  --data "D:/skein-data"
```

脚本建目录、路由、知识库骨架、机械地图和档案索引，**但不写任何项目档案**——档案索引里每个仓都会停在 `TODO`。

**两者不等价。** 脚本只能读文件系统和 Git 元数据，读不出「这个仓解决什么问题、从哪进、怎么跑」。这些必须由 agent 读少量文件后写。只跑脚本 = 库能用、但新 agent 接手仍需自己摸一遍。

## 先找到脚本

技能可能被手工复制时漏了文件。按顺序找，命中就停：

```bash
INIT=""
for d in "$PWD/.claude/skills" "$PWD/.codex/skills" "$PWD/.workbuddy/skills" \
         "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.workbuddy/skills"; do
  if [ -f "$d/project-memory/scripts/init.sh" ]; then INIT="$d/project-memory/scripts/init.sh"; break; fi
done
[ -n "$INIT" ] || { echo "[HANDOFF_GAP] 找不到 scripts/init.sh，技能可能装漏了文件"; exit 1; }
```

都找不到 → 报 `[HANDOFF_GAP]` 并停下。**不要凭记忆手写建库命令**——那就又变成两份实现，迟早对不上。

## 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `--workspace <目录>` | 当前目录 | 工作区根，可以包含多个 git 仓 |
| `--data <目录>` | `~/skein-data` | 数据家；也可以设 `SKEIN_DATA_HOME` |
| `--prefix <前缀>` | `sk` | 任务库前缀，只在装了 `bd` 时用 |

路径用正斜杠，Windows 也写 `D:/skein-data`。脚本会自己把 `/c/...` 转成 `C:/...` 再写进路由。

## 它做什么

1. 从工作区根向下扫一遍：子目录里还有 `AGENTS.local.md` 就**停下并列出清单**，等用户决定（它不会删别人的路由）
2. 建 `<数据家>/<工作区名>/{store,checkpoints,backups,worktrees}`
3. 建 `kb/{facts,decisions,runbooks,journal,proposals,archive}`
4. 写归属标记 `.skein-scope`（内容是工作区绝对路径）
5. 工作区根没有 `AGENTS.local.md` 才写；已有就沿用并只核对键
6. 工作区根**本身是 git 仓**时，把 `/AGENTS.local.md` 写进 `.gitignore`（这个文件要提交，换机才继续生效；不要只写 `.git/info/exclude`，克隆不带走）
7. `kb` 独立 `git init`，写首版 `INDEX.md` / `current.md`
8. 生成工作区地图 `kb/facts/workspace-map.md`（顶层不足 3 项就跳过）
9. 生成项目档案索引 `kb/facts/projects/INDEX.md`：工作区根自身（如果它就是一个 git 仓）加下面两层的每个 git 仓，一行一个，状态全标 `TODO`
10. 装了 `bd` 就 `bd init`，没装就提示怎么补

## 工作区地图

建库时会顺手写一张 `kb/facts/workspace-map.md`，给第一次进这个工作区的人看的：

| 条目 | 类型 | 最后提交 | 顶层条目数 | 备注 |
|---|---|---|---:|---|
| `web-first-ask-browser-mode` | git 仓 | 2026-11-20 | 24 | package.json: web-first-ask@0.2.1 |
| `mcp-shared-browser-release` | git 仓 | 2026-11-19 | 15 | package.json: chatgpt-web-mcp@0.7.13 |
| `token-bench-20261116` | 目录 | - | 12 | 无 |

规则就这么几条：

- **只扫顶层一层，不含隐藏项**，跳过 `node_modules` / `.venv` / `dist` / `build` / `target` / 符号链接
- **不算递归体积**：一个 40 MB 的目录 `du -sh` 要 20 秒，五个就能把建库拖到两分钟。改成「顶层条目数」，同样能看出哪些目录异常臃肿
- **备注只做机械摘取**：先 `package.json` 的 `name@version`（同名副本靠它区分），再 `README.md` 的第一个正文行（`#` 标题也认），都没有写「无」
- **有效条目少于 3 个就不生成**，只有一两个目录时 `ls` 更快
- **文件是生成的，不要手工改**，重跑 `init.sh` 会覆盖；要补用途写 `facts/workspace-notes.md`
- 单独刷新不用重跑整个建库：`bash <技能目录>/project-memory/scripts/map.sh --workspace <工作区>`

地图是**快照，不是当前事实**。文件头写了生成时间；agent 要动手前仍要核对目标目录和 `git rev-parse HEAD`，冲突时以现场为准。

## 逐仓建档（脚本做不了这一段）

脚本跑完只是骨架。要让人能直接接手，还得给**目标仓**写一份档案。

规则、模板、上限、黑名单全在 `references/brief.md`，这里只说流程。

### 先定目标仓

**这一步不能跳过，也不能靠活跃度猜。**

- 工作区只有一个仓 → 就是它
- 用户说了「我要接手 X」→ 就是 X
- 用户没说、仓又有多个 → **问一句**「这次要接手哪个仓」，不要自作主张把所有仓都建一遍
- 用户要批量预建档 → 才按 `brief.md` 的三条判据筛选「先建哪些」，其余留 `TODO`

目标仓**直接完整建档，不看提交时间**。两年没动的仓最需要这份档案。

### 索引里怎么认仓

- **相对路径是 `.`**：工作区根自己就是项目仓（单项目建库的常见形态），档案文件名用工作区目录名
- **`group/alpha`**：第二层的仓，档案文件名用 `<仓名>.md`；同名仓自动带路径 hash
- **扫到第二层为止**：第三层及更深的仓不进索引。真有需要，把工作区根指到更近的那层，或在 `facts/` 里手工补一条
- **linked worktree 和子模块**：`.git` 是文件也算仓；子模块单独成行，按普通仓建档

### 顺序

1. 读 `kb/facts/projects/INDEX.md`，找到目标仓那一行
2. **按 `brief.md` 读，读到「有足够证据可信地填写必需字段」就停**，不是「把模板空格填满」就停。用推断填满再标 `READY` 是最坏的结果
3. 读取顺序（每项读到够用就停）：
   - 项目规则文件：`AGENTS.md` / `CLAUDE.md` / `.cursorrules` / `CONTRIBUTING.md`——有就读，agent 最需要的往往是这些约束，不是 README
   - `README.md`：前 60 行，找「是什么」和「怎么跑」
   - 清单文件（`package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile`）：**按结构取键，不套行数上限**。`package.json` 用 `node -e 'const p=require("./package.json");console.log(JSON.stringify({name:p.name,version:p.version,bin:p.bin,main:p.main,scripts:p.scripts},null,1))'`；`pyproject.toml` / `Cargo.toml` 用 `grep -nE '^\[|^(name|version|scripts)'`；`Makefile` 取 `^[A-Za-z0-9_.-]+:` 的目标名。这些文件常超过 400 行，`scripts` 就在后半段
   - 目录结构：只看两层；根目录只有 workspace 声明（monorepo）时，按 `workspaces` 或 `apps/` `packages/` 再多看一层
   - 最多 3 个入口文件：先 `grep -nE 'int main|if __name__|func main|\.listen\(|createServer|program\.command'` 找候选，再读候选文件的相关片段。**不要指望入口在前 40 行**——Python 的 `__main__` 在末尾，TS 的路由注册常在百行之后
   - 环境前置（有就取，没有就跳过）：`.nvmrc` / `.python-version` 取版本号；`.env.example` 只取变量名；`docker-compose.yml` 只取服务名与端口；`.github/workflows/*.yml` 只取 `run:` 行
4. 入口或运行方式还没找到时，**允许一次定向补读**：针对已经发现的线索去找（比如 README 提到 `docker compose up` 就去看 compose 文件），不要重新全仓扫一遍
5. 按 `brief.md` 的写入顺序落盘：临时文件 → 校验（含 `READY` 五条准入）→ 原子改名 → 更新索引 → 限定路径 `git add` + `commit --only` → 检查退出码

### 预算

- 单仓累计摘取 **不超过 8 KiB 文本**。超了就停，没读的部分写进「缺口」，状态标 `PARTIAL`
- 读大文件前先看行数；超过 400 行只读前 40 行 + 目录。**清单文件是例外**，按结构取键，不受这条限制
- 定向补读最多一次，仍不够就带着缺口收尾——**不允许用推断把缺口补成 `READY`**

### 完成判据

看**目标仓**那一行，不是看全表：

```bash
grep -F '| `'"$TARGET"'` |' "$KB/facts/projects/INDEX.md"
```

| 结果 | 含义 |
|---|---|
| 目标仓 `READY` | 建完了，可以宣布「接手准备完成」 |
| 目标仓 `PARTIAL` | 建了一半，把缺口原样报给用户 |
| 目标仓还是 `TODO` | 没建，不要说「库已建好」 |

其他仓保持 `TODO` 是正常的，不是缺陷。**`grep -c '| TODO |'` 不再作为完成判据**——那是「全部预建档」才需要的。

### 中断了怎么办

建到一半停下是正常的（上下文用完、用户走了）。恢复时**先看文件，再看索引**：

- 索引写 `READY` 但文件不存在或字段不全 → 改回 `TODO`
- 索引写 `TODO` 但文件完整 → 核对后改成真实状态
- 有 `.tmp` 残留 → 删掉重写，不要续写

细节在 `brief.md` 的「写入与中断恢复」。

### 多仓工作区

批量预建档时，**每次独立写盘并提交**。不要攒到最后一起写——中途断掉会全丢。

只建了目标仓、其余仍是 `TODO`，是正常状态，在 `current.md` 里写清「已建 X，未建 Y」。

## 它会拒绝的情况

拒绝时输出 `[HANDOFF_GAP]`，退出码 1，**不改任何东西**：

| 情况 | 为什么拒绝 |
|---|---|
| 子目录里还有 `AGENTS.local.md` | 会遮住工作区这份，必须先由用户决定去留 |
| 数据家落在 git 工作树里 | 私有库会被提交、可能被推送 |
| 数据目录已属于另一个同名工作区 | 两个「项目」会共用一份库（看 `.skein-scope`） |
| 数据目录有内容但没有归属标记 | 来历不明，不接管 |
| `kb` 已配置远程 | 私有库不该有远程 |
| `AGENTS.local.md` 已被 git 跟踪 | 忽略规则对已跟踪文件无效，先 `git rm --cached` |

## 验收

| 项 | 命令 | 期望 |
|---|---|---|
| 路由 | `cat <工作区>/AGENTS.local.md` | 五个键都有值，路径是 `C:/...` 或 `/home/...` |
| 作用域唯一 | `find <工作区> -mindepth 2 -name AGENTS.local.md` | 无输出 |
| 忽略 | 工作区是仓根时 `git check-ignore -v AGENTS.local.md` | 有一行输出 |
| 归属 | `cat <数据家>/<工作区名>/.skein-scope` | 等于工作区绝对路径 |
| 库独立 | `git -C <kb> remote -v` | 无输出 |
| 库已提交 | `git -C <kb> log --oneline` | 至少一条 |
| 任务库 | `bd -C <store> list` | 不报错（没装 bd 可跳过） |
| 地图 | `head -8 <kb>/facts/workspace-map.md` | 有生成时间和表格；顶层不足 3 项时没有这个文件 |
| 档案索引 | `cat <kb>/facts/projects/INDEX.md` | 工作区根自身（若是仓）加两层的每个 git 仓一行；状态列是 `TODO` / `PARTIAL` / `READY` |
| 目标仓建档 | `grep -F '\| \`<目标仓名>\` \|' <kb>/facts/projects/INDEX.md` | 该行是 `READY`；`PARTIAL` 要带缺口，`TODO` = 没建 |
| 档案上限 | `wc -c -l <kb>/facts/projects/*.md` | 单份 ≤ 4 KB / 70 行 |

再让 AI 说一句：「读一下 `AGENTS.local.md`，告诉我 store 和 kb 在哪。」说得对就通了。

## 建库之后

库的内容（分类、事实、决策、真实提交）归本技能继续管，脚本只建骨架：

- **项目档案**：改过入口、命令或约束，用 `brief.md` 的刷新规则按需更新；巡检文件的内容哈希没变，不用动
- 新事实写 `facts/`，新决策写 `decisions/`，可复用步骤写 `runbooks/`
- `INDEX.md` 超过 1000 tokens 就该整理，读 `references/curate.md`
- 旧库搬进来读 `references/migration.md`

## 常见错误

- **给每个 git 仓都建一个库。** 库是按工作区建的；子仓共享同一份，任务标题带 `[子仓名]` 区分
- **在子目录又放一份 `AGENTS.local.md`。** 会遮住工作区那份，技能向上找时就停了
- **让安装脚本顺手建库。** `install.sh` 只复制技能，建库只走这里
- **两个同名工作区共用一个数据目录。** 比如 `D:/a/项目` 和 `E:/b/项目`；`.skein-scope` 会拦住，换 `--data` 即可，别手工删标记
- **手工往地图里加备注。** 下次 `init.sh` 会把整张表覆盖掉；说明写到 `facts/workspace-notes.md`
- **把档案写成第二份 README。** 超过 4 KB / 70 行就是写多了，细节留指针，不复制正文
- **只跑脚本就以为建完了。** 目标仓那行还是 `TODO` 就没建完，新 agent 接手仍要现场摸
- **没定目标仓就开始逐仓建档。** 先问「这次接手哪个」，再动手；不要靠活跃度猜
- **给不用的仓写 PARTIAL 占位。** 没有入口和命令的档案比 `TODO` 更糟——它看起来建过了。没用到的仓保持 `TODO`
- **用推断把模板填满再标 `READY`。** `READY` 的五条准入条件不成立，就必须是 `PARTIAL`
