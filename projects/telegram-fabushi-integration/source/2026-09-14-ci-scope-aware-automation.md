# 2026-09-14 用户需求：自动化测试按变更范围运行

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Proposed task: `TFI-CI-OPT-015`
- 来源：用户在 2026-09-14 明确要求“自动化测试需要能够自动识别变更的范围，不是范围内的不要跑，节省时间”。

## 目标

在不绕过受保护主线必需检查、不让 Merge Queue 等待缺失状态的前提下，让主仓库工作流先识别 PR/merge queue/main push 的变更范围，再只启动受影响的测试矩阵。未受影响的 job 必须以可审计的 skipped/success 结果结束，并由稳定的聚合检查返回成功。

## 本轮优先范围

优先治理当前会触发无关重任务的工作流：

- Computer control security gate：Chrome-only 变更不启动 Rust contracts、platform-worker 和 Linux desktop 矩阵。
- Electron desktop quality gate：Chrome-only 变更不启动 Electron Linux PR 旅程。
- Global Dharma Web Service Contract：项目治理文档变更不安装 backend/web/commerce 依赖。
- GBF security closure：非 GBF/Computer Control 安全边界的 Chrome-only 变更不启动完整闭环。
- 保持 Chrome Extension Web Store workflow 对 Chrome 目录的精确覆盖。

## 安全边界

- workflow 本身仍在 PR 上产生稳定的 scope 和 result 检查，不能用顶层 path filter 让受保护检查完全消失。
- workflow、scope 配置、全局工具链/锁文件和安全边界变更采用保守策略，触发相关全量检查。
- main push 的正式发布/证据生产路径继续保留，不能因 PR 快路径优化而削弱 post-main delivery。
