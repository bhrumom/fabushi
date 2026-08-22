# GBF-001 Evidence

## Source observations

- GitHub 中已确认 `grok-bot-latest-source-fusion` branch 存在。
- GitHub 中已确认 `grok-bot-0.16-source-fusion` branch 存在。
- latest source branch 暴露 `desktop/electron/main.cjs`, `host-process.cjs`, `preload.cjs`, `native-capability-handlers.cjs`, `native-edge.cjs`, offline ASR 以及 `desktop/e2e`。
- current `main` 同样包含对应 Electron 文件并有后续变化/新增，因此 historical source branch 仅作为 input，不作为可覆盖 main 的权威快照。
- 2026-08-22 新 enterprise project-folder standard 已进入 main；本任务二次对齐其 mandatory scaffold/metadata/management/evidence/runbook 要求。

## Project commits

- Initial scaffold culmination: `c7086a10df514e78787cbdcf57cd0ee80bf4f444`.
- Enterprise baseline: `b03cfeea7e4b0aa7574eccd59ba82cbcfd8f320b`.
- Execution governance: `f214c1dd98d5e61055f100305d1fb3adb215f260`.
- Exact enterprise-standard alignment: recorded by the next commit/PR after this file update.

## Pending evidence

- Project PR number/head SHA
- Required `CI result`
- Protected-main/merge-queue result
- Merge commit SHA
- Post-merge `main` file verification

这些 pending 项未完成前 GBF-001 保持 `IN_PROGRESS`。
