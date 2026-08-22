# 02 Grok Bot 能力目录

初始目录基于仓库已验证的历史融合分支建立，M1 必须继续扩展到文件级 100% 盘点。

| Domain | 已观察输入 | 目标 |
|---|---|---|
| Electron shell | `desktop/electron/main.cjs` | 收敛系统生命周期/IPC |
| Preload bridge | `preload.cjs` | 最小化版本化 contract |
| Host process | `host-process.cjs` | 统一 host capability runtime |
| Capability handlers | `native-capability-handlers.cjs` | 权限化本机工具 |
| Native edge | `native-edge.cjs` | 与 Mahayana/native runtime 统一 |
| Edge IPC | `edge-ipc.cjs` | 单一 IPC schema |
| Offline ASR | `offline-asr.cjs` + tests | 保留有价值本机语音能力 |
| Desktop E2E | `desktop/e2e` | 转化为正式回归套件 |
| UI/rendering | `desktop/src/**` | Fabushi UI 单一实现 |
| Computer control | 历史 host/native/tool 链 | capability-gated 跨平台控制 |
| Agent orchestration | 历史 Grok coordinator/host 思路 | Mahayana sovereign runtime |
| Avatar/animation | 历史 Grok 风格动态表现 | Fabushi 自研状态驱动引擎 |

每项必须最终归类为 `MAIN_HAS`、`SOURCE_BETTER`、`MAIN_SUPERSEDES`、`MIGRATE_REWRITE`、`DEPRECATE` 或 `PROVENANCE_BLOCKED`。
