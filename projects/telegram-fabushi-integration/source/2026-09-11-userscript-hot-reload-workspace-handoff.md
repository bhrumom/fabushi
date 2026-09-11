# 2026-09-11 油猴脚本热更新后的持续目标断链

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Intake: 用户截图、现场电脑插件只读核对，2026-09-11 Asia/Shanghai
- Related implementation: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`

## 用户原始要求（语义保真）

持续目标的 Work 会话已经结束并产生完整最终回复，但插件没有成功开启新的验收会话开展下一步；需要查明并修复，让插件持续运作。

## 现场事实

- 目标会话 `https://chatgpt.com/c/6aa40d6e-4c0c-83e8-b016-9df98acb467e` 已有完整 assistant 最终回复和回复操作控件。
- 同页出现多个“Fabushi 脚本”启动按钮，展开的实例显示当前标签页无任务、已暂停、扫描 0 次。
- 原任务记录出现在另一空白标签页的“恢复任务记录”列表，表明任务数据未丢失，但原 `ownerTabId` 未被当前文档实例继承。
- 当前现场仍运行旧版 2.9.3 UI；该现象对应版本替换/重复注入时的实例交接路径。

## 规范化需求

- `TFI-USR-HR-R01`: 同一文档替换活动脚本实例时，必须等待旧实例的工作区 Web Lock 真正释放后，再用原 session `tabId` 重取锁。
- `TFI-USR-HR-R02`: 只有没有同文档旧实例且锁被其他文档持有时，才按复制标签页规则生成新 `tabId`。
- `TFI-USR-HR-R03`: 启动和关闭必须清理同文档全部重复工作台根节点/样式节点，不得留下多个启动按钮或由旧实例删除新实例 UI。
- `TFI-USR-HR-R04`: 热更新后必须沿用 `autoResume`、selected/current 可恢复任务并继续 Work 完成 → 新验收会话状态机。
- `TFI-USR-HR-R05`: 回归覆盖异步锁释放竞态、真正复制标签页隔离、重复根节点清理和持续目标自动恢复。

## 非目标

- 不修改 Fabushi 应用本体。
- 不绕过或窃取其他真实标签页仍持有的锁。
- 不改变 Work/规划 prompt 或验收 JSON 契约。

