# 2026-08-24 — Main post-merge E2E visual evidence requirement

## Source

User requirement, 2026-08-24:

> 要求合并进main的E2E测试需要产出详细的截图和操作视频，方便回溯。

Follow-up clarification asked whether this requirement had been written into root `AGENTS.md`.

## Durable requirement

For every required E2E execution associated with a change accepted into canonical `main`, visual/debug evidence is mandatory for both passing and failing journeys, not failure-only diagnostics.

Required evidence:

1. Detailed, step-labelled screenshots at meaningful user-journey checkpoints.
2. A complete operation recording covering the tested journey; segmented recordings are acceptable when the platform recorder has a duration limit, but the segments together must cover the full journey.
3. Action/trace evidence and platform-native test reports/logs where supported (for example Playwright trace/report, Android instrumentation report/logcat, iOS `.xcresult`).
4. Metadata tying the evidence to the exact canonical `main` SHA, application version, platform, workflow run/job, test/journey name, and timestamp.
5. Upload evidence with an `always()`-equivalent path so diagnostics survive failures as well as successes.
6. Evidence must be retained as GitHub Actions artifacts for retrospective debugging; target 90-day retention for canonical-main E2E evidence where repository/organization retention policy permits, otherwise use the maximum permitted retention and record that constraint.

A required post-main E2E gate is not considered evidentially complete if the required screenshots/video/report bundle is missing, even when the test assertions themselves passed.

## Platform expectations

- Electron/Desktop: retain video for every canonical-main E2E journey, detailed screenshots, Playwright trace, and HTML/test result report.
- Android: retain emulator operation recording (segment if needed), step screenshots, instrumentation results, and relevant logcat/debug evidence.
- iOS: retain Simulator operation recording, step screenshots, `.xcresult`, and relevant crash/debug logs.

## Project mapping

- Project: `FAB-P0003`
- Project key: `FCM`
- Task: `FCM-009`
- This source extends the post-main delivery evidence requirements; it does not make the optional previous-installed-client updater journey mandatory.
