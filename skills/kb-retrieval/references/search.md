# 大知识库检索与维护细则（kb-retrieval）

## 检索阶梯命令参考

1. **索引定位**：读 `$KB/INDEX.md`（若配置了跨项目 `global_kb` 且问题跨项目，再读 `$GLOBAL_KB/INDEX.md`）。
2. **关键词检索**：
   ```bash
   rg -n "<关键词>" "$KB/facts" "$KB/decisions" "$KB/runbooks"
   ```
3. **`ai-memory` 检索（若已安装，默认 0 LLM）**：
   ```bash
   ai-memory search "<自然语言或术语>"
   ```
4. **`qmd` 混合检索（仅当文档 >50 篇或 >1MB 时启用）**：
   建集合必须用目录白名单，严禁 `**/*.md`：
   ```bash
   qmd collection add "$KB" --name skein-kb \
     --mask "INDEX.md,facts/*.md,decisions/*.md,runbooks/*.md"
   qmd search "<词>" -c skein-kb -n 5
   qmd get <file>:<from>:<count>
   ```
   改过 `--mask` 必须 `qmd collection remove skein-kb` 后重建。

## 整理阈值（curate）

出现以下任一情况时执行轻量整理：
- `INDEX.md` 超过 80 行或 1000 tokens
- `facts/` 出现自相矛盾条目（以最新实测为准，旧条目移入 `archive/`）
- `proposals/` 积压超过 5 份未合并提案（由写者逐一核实合并或关闭）
