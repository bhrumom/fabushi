# GBF-001 Evidence

## Source observations

- GitHub 中已确认 `grok-bot-latest-source-fusion` branch 存在。
- GitHub 中已确认 `grok-bot-0.16-source-fusion` branch 存在。
- latest source branch 暴露 `desktop/electron/main.cjs`, `host-process.cjs`, `preload.cjs`, `native-capability-handlers.cjs`, `native-edge.cjs`, offline ASR 以及 `desktop/e2e`。
- current `main` 同样包含对应 Electron 文件并有后续变化/新增，因此 historical source branch 仅作为 input，不作为可覆盖 main 的权威快照。
- 2026-08-22 enterprise project-folder standard 已进入 main；GBF-001 已按其 mandatory scaffold/metadata/management/evidence/runbook 要求二次对齐。

## Project implementation commits

- Initial scaffold culmination: `c7086a10df514e78787cbdcf57cd0ee80bf4f444`.
- Enterprise baseline: `b03cfeea7e4b0aa7574eccd59ba82cbcfd8f320b`.
- Execution governance: `f214c1dd98d5e61055f100305d1fb3adb215f260`.
- Exact enterprise-standard alignment/head: `4a70e771b9f5f166e49b4001d2d8c9e9ad6164ad`.

## Pull request / CI

- PR: #1982 — `docs(project): establish Grok Bot full-fusion project baseline`.
- Changed scope: only `projects/grok-bot-fabushi-integration/**` in the validated main-vs-head compare.
- PR CI: run #6089 (`32557228982`) completed success.
- Jobs: `Classify CI changes` success; required `CI result` success; unrelated runtime-domain jobs correctly skipped on docs-only classification.

## Protected main merge

- Auto-merge enabled.
- Direct merge API confirmed PR was in merge queue, so branch protection was not bypassed.
- PR #1982 merged at 2026-08-22 06:33:20Z.
- Merge commit: `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c`.
- Git commit signature verification returned valid for the GitHub merge commit.

## Post-merge canonical verification

After merge, `main:projects/grok-bot-fabushi-integration/PROJECT.yaml` was fetched successfully and contains project id/slug/authoritative main path/source branches. `main:.../source/grok-bot融合优化.txt` was also fetched successfully and exactly preserves the original source requirement.

Result: GBF-001 baseline acceptance passed. This evidence closes only M0 project-bootstrap; it does not claim M1-M8 runtime migration completion.
