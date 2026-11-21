# 检索细节与工具坑

## 路径常量

```bash
PROJ="${PROJ:-$(git rev-parse --show-toplevel 2>/dev/null)}"
LOCAL="$PROJ/AGENTS.local.md"
[ -f "$LOCAL" ] || { echo "[HANDOFF_GAP] 缺 $LOCAL"; exit 1; }
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -1 | tr -d '\r'; }
KB="$(kv kb)"
[ -n "$KB" ] || { echo "[HANDOFF_GAP] 缺 kb 键"; exit 1; }
QMD_CACHE="$HOME/.cache/qmd"      # 本机上是指向 H 盘的 junction
QMD_CONF="$HOME/.config/qmd"
ESOUT="${TEMP:-/tmp}/es-out.json"
```

## 六级的完整命令

**1. 导航**

```bash
cat "$KB/INDEX.md" "$KB/current.md"
```

**2. 文件名（只记得叫什么）**

```bash
es -path "$KB" "<片段>" -n 20 -export-json "$ESOUT"
python -c "import json,sys;[print(x['filename']) for x in json.load(open(sys.argv[1],encoding='utf-8'))]" "$ESOUT"
```

**3. 内容精确词**

```bash
rg -n "<词>" "$KB/INDEX.md" "$KB/current.md" "$KB/facts" "$KB/decisions" "$KB/runbooks"
```

**4. 换词 / 跨文件（50 篇以上才开）**

```bash
XDG_CACHE_HOME="$QMD_CACHE" QMD_CONFIG_DIR="$QMD_CONF" qmd search "<词>" -c agents-kb -n 5
```

**5. 回读命中段**

```bash
XDG_CACHE_HOME="$QMD_CACHE" QMD_CONFIG_DIR="$QMD_CONF" qmd get facts/agent-env.md:1:60
```

**6. 语义兜底**

```bash
XDG_CACHE_HOME="$QMD_CACHE" QMD_CONFIG_DIR="$QMD_CONF" qmd vsearch "<描述>" -c agents-kb -n 5
```

## `es` 的三个坑

1. **stdout 是 GBK。** UTF-8 终端里看到 `H:\AI������\` 这种乱码，内容其实是对的。要读内容必须 `-export-json` 再按 UTF-8 解析。
2. **不带 `-path` 就是全盘搜。** 会捞出一堆 `workspace\sessions\*.modify_backup_meta` 之类的备份噪音。
3. **路径不存在时返回 rc=0 且不生成文件。** 不能靠退出码判断成功，要先确认路径存在，或把「文件不存在」当成 0 条结果。

前置条件：Everything 必须以**用户态**运行并开 IPC。服务态会报 `Error 8: Everything IPC not found`。做不到就跳过第 2 级直接用 `rg`。

## `qmd` 的三条 mask 铁律

1. **必须白名单 + 显式逗号 + 单层 glob**：`INDEX.md,current.md,facts/*.md,decisions/*.md,runbooks/*.md`
2. **不能用 `**/*.md`**：实测一次吃进 327 个文件（含 `_tmp`、`.workbuddy`）
3. **不能用 `{a,b}/**/*.md`**：实测索引到 45 个，实际只有 3 个

改 mask 要 `qmd collection remove` 重建，`qmd update` 不清理失效条目。

## 什么时候才值得开 QMD

知识库到 **50 篇或 1 MB** 以上，且 `INDEX.md` + `rg` 已经盖不住同义表述或跨篇关联时。小库用前三级就够，开 QMD 是净负担。

QMD 原生 Windows 可跑，**不需要 WSL**。但每次调用都要带 `XDG_CACHE_HOME` / `QMD_CONFIG_DIR`，否则找不到集合。
