# Stable Requirements

| ID | Requirement | Acceptance |
|---|---|---|
| GBR-001 | 完整盘点 Grok Bot 历史融合源码与功能 | 能力矩阵覆盖来源分支及当前 main，零未分类关键模块 |
| GBR-002 | Grok 独有有效能力融合进 Fabushi 正式架构 | 每项能力有目标模块、实现 PR 与测试证据 |
| GBR-003 | 不保留第二套长期 Agent/Host/会话运行时 | 架构审计无重复主通道 |
| GBR-004 | Electron main/preload/IPC/host 能力安全收敛 | IPC allowlist、权限与敏感输入测试通过 |
| GBR-005 | 电脑控制与本机执行能力可审计、可撤销 | capability grant/revoke/deny E2E 通过 |
| GBR-006 | 动态头像/动画引擎成为 Fabushi 自研可维护模块 | 无运行时 Grok 依赖，有独立状态机与性能测试 |
| GBR-007 | 所有迁移能力具有自动化验证 | 单测/集成/E2E/CI 按风险等级通过 |
| GBR-008 | 来源与许可证边界可审计 | 每类来源记录许可证/重写/替代决策 |
| GBR-009 | 历史融合分支不得整分支覆盖 main | 只允许原子 PR/能力迁移，CI 防回归 |
| GBR-010 | 发布后可回滚 | 每个高风险能力有 feature flag 或明确 rollback 路径 |
| GBR-016 | 安装后的桌面设备可由同账号全平台发现，并经明确配对/开关授权由人或 Bot 远控；桌面包内置完整语义 Computer Use | 设备在线与控制授权分离；全平台 package/E2E/security/Release 证据通过 |
