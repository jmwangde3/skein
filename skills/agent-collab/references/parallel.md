# 并行协作与冲突合并细则（agent-collab）

## 模式 A：独立子任务并行合并清单

合并只能由单一集成者执行：

1. 确认两个子任务均已在各自 worktree 完成验证并提交（无未提交脏文件）。
2. 切回主分支依次合并（保留分叉历史便于回滚）：
   ```bash
   git -C "$REPO" checkout main
   git -C "$REPO" merge --no-ff feat/<task-a>
   git -C "$REPO" merge --no-ff feat/<task-b>
   ```
3. **冲突分级处理**：
   - 同文件同段冲突 → 停下交人工裁决，禁止 `ours`/`theirs` 盲丢。
   - 同文件不同段自动合并 → 必须重跑测试并由对应任务负责方复核语义。
   - 知识库提案 → 由点名的唯一 KB 写者逐条核实 `proposals/` 后合并并提交。
4. 合并验证通过后清理 worktree 并关闭看板任务：
   ```bash
   skein-cli wt-clean <task-a>
   skein-cli wt-clean <task-b>
   ```
5. 提醒用户通过 `skills-manager` 手动卸载 `agent-collab`。

## 模式 B：同任务实时配合核对清单

- 开工前明确声明：**谁是唯一写者，谁是只读观察者**。
- 只读观察者严禁运行会改写工作树的命令（如格式化、自动修复、`git checkout`）。
- 配合结束后提醒用户通过 `skills-manager` 手动卸载 `agent-collab`。
