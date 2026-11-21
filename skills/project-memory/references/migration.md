# 旧库迁移

## 五条规则

1. **先整目录备份。** 任何移动或改写之前，先把旧库整份复制到安全位置。搬完核对过再删原件。
2. **按内容分类，不按编号机械搬。** 旧库的 `00_` `05_` `15_` 是旧编号，不是分类。按「这是事实 / 这是决策 / 这是流水 / 这是过时方案」重新分。
3. **未验证的陈述不升级成事实。** 旧文档里的推断、估算、过时配置，不能直接写进 `facts/`。要么标「未验证」，要么留在 `archive/`。
4. **旧库保留到核对完成。** 新库跑通、内容抽样核对过之后，才动旧文件。
5. **归档与提炼分离。** 原文进 `archive/legacy-kb/`，新文件是提炼重写，不是复制粘贴。

## 典型映射

| 旧 | 新 |
|---|---|
| 基线 / 总览 | `INDEX.md`（导航）+ `facts/`（事实） |
| 进度仪表盘 | `current.md`（**删掉任务状态表**，改指向 Beads） |
| 环境/配置分册 | `facts/<主题>.md` |
| 会话日志 / 流水 | `journal/<年月>.md`，append-only |
| 历史方案、过程档案 | `archive/plans/`、`archive/legacy-kb/` |

## 搬完之后必做

```bash
# K 是 AGENTS.local.md 里 kb 指向的路径，见 setup.md 第 0 步
git -C "$K" -c core.autocrlf=false add -A
git -C "$K" -c core.autocrlf=false commit -m "kb: 从旧库迁移"
OLD="旧文件名"     # 占位符，换成真实的旧文件名
rg -n -F "$OLD" "$K/INDEX.md" "$K/current.md" "$K/facts" "$K/decisions" "$K/runbooks"   # 确认没有断链
```

`archive/` 里的旧文件名引用不用改，那是历史原文；但要确认 `archive/README.md` 说清了「按文件名找，别信链接」。

**相对链接会断。** 旧文档里的 `[入口](AGENTS.md)` 这类链接在搬家后全部失效。在 `archive/README.md` 里写明「按文件名找，别信链接」。

## 不该迁进来的

- 凭证、token、登录态
- 已被公开推送过的项目文档（它们属于代码仓，不属于私有知识库）
- 一次性试验的中间产物（只留结论与证据路径）
