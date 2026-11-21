# 检索细节与工具坑

## 路径常量

```bash
# 从当前目录向上找作用域根：第一个含 AGENTS.local.md 的目录
SCOPE=""
d="$(pwd -P)"
while :; do
  if [ -f "$d/AGENTS.local.md" ]; then SCOPE="$d"; break; fi
  p="$(dirname "$d")"
  if [ "$p" = "$d" ]; then break; fi
  d="$p"
done
[ -n "$SCOPE" ] || { echo "[HANDOFF_GAP] 没找到 AGENTS.local.md（应在工作区根）"; exit 1; }
LOCAL="$SCOPE/AGENTS.local.md"
kv() { sed -n "s/^$1:[[:space:]]*//p" "$LOCAL" | head -n 1 | tr -d '\r'; }
KB="$(kv kb)"
[ -n "$KB" ] || { echo "[HANDOFF_GAP] 缺 kb 键"; exit 1; }

# QMD 的两个目录：缓存家目录（qmd 自己会在下面建 qmd/）+ 配置目录本身
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
QMD_CONFIG_DIR="${QMD_CONFIG_DIR:-$HOME/.config/qmd}"
QMD() { XDG_CACHE_HOME="$XDG_CACHE_HOME" QMD_CONFIG_DIR="$QMD_CONFIG_DIR" qmd "$@"; }

ESOUT="${TEMP:-/tmp}/es-out.json"
COLL="${COLL:-skein-kb}"     # 与 README 里 qmd collection add --name 保持一致
```

## 六级的完整命令

**1. 导航**

```bash
cat "$KB/INDEX.md" "$KB/current.md"
```

**2. 文件名（只记得叫什么）**

需要 Everything（`es`）。没有就跳到第 3 级，别卡在这。

```bash
Q="<片段>"          # 占位符，换成真实关键词
if command -v es >/dev/null 2>&1 && [ -d "$KB" ]; then
  rm -f "$ESOUT"
  es -path "$KB" "$Q" -n 20 -export-json "$ESOUT" || true
  [ -f "$ESOUT" ] && python -c "import json,sys;[print(x['filename']) for x in json.load(open(sys.argv[1],encoding='utf-8'))]" "$ESOUT"
else
  echo "es 不可用，跳过文件名检索" >&2
fi
```

**3. 内容精确词**

```bash
Q="<词>"            # 占位符
if command -v rg >/dev/null 2>&1; then
  rg -n -F "$Q" "$KB/INDEX.md" "$KB/current.md" "$KB/facts" "$KB/decisions" "$KB/runbooks"
else
  grep -rn -F "$Q" "$KB/INDEX.md" "$KB/current.md" "$KB/facts" "$KB/decisions" "$KB/runbooks"
fi
```

**4. 换词 / 跨文件（50 篇以上才开）**

需要 QMD。没装就退回第 3 级换词再搜，别报错停住。

```bash
Q="<词>"
command -v qmd >/dev/null 2>&1 && QMD search "$Q" -c "$COLL" -n 5
```

**5. 回读命中段**

```bash
QMD get facts/agent-env.md:1:60
```

**6. 语义兜底**

```bash
D="<描述>"
command -v qmd >/dev/null 2>&1 && QMD vsearch "$D" -c "$COLL" -n 5
```

第 4–6 级返回「找不到集合」时，说明这个项目还没建集合，或集合名不是 `skein-kb`——退回前三级，不要现场重建索引。

## `es` 的三个坑

1. **stdout 是 GBK。** UTF-8 终端里，中文路径会显示成一串问号或方块，内容其实是对的。要读内容必须 `-export-json` 再按 UTF-8 解析。
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
