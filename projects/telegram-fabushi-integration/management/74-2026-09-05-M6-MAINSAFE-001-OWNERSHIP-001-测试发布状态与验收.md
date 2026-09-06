# TFI-M6-MAINSAFE-001-OWNERSHIP-001 测试发布状态与验收

日期：2026-09-05（+08:00）

## 状态

- Protected canonical-main merge: **PASS**
- Accepted canonical-main SHA: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Exact-main packaged acceptance: **FAIL**
- Native/mobile acceptance: **FAIL**
- Evidence completeness: **FAIL**
- Test/pre-release delivery: **NOT CREATED**
- Stable release: **NOT ATTEMPTED**
- Final classification: **TEST-FAILED / PACKAGED-BLOCKED / NATIVE-IOS-FAILED / EVIDENCE-INCOMPLETE**

## 合并验收

产品 PR #2336 的 reviewed head 为 `8760b7587f6d576262e5993a72b5c5112ff595db`。受保护 `main-merge-queue` ruleset id `15857448` 要求 `SQUASH + ALLGREEN` 和 required status `CI result`。本轮仅对 #2336 使用仓库 `automerge` 标签，未 bypass、未 direct merge、未 rebase/retarget/force-push。

Merge-group canonical CI run `33920323994` 的 `CI result` job `101177336627` 成功；fallback run `33920289602` 的 `CI result` job `101176799668` 成功。#2336 于 `2026-09-04T21:18:43Z` 合并，随后 GitHub `main` 读回为 `dbf22b467d35c8af2a074896c355a41993c8c191`。

## Exact-main packaged 验收

Accepted main 的应用版本为 `1.2.22`，`androidVersionCode=29`，`iosBuildNumber=29`。

Electron desktop quality gate run `33920502884`：**FAILURE**。

- Linux job `101177474099`: FAILURE；在打包/E2E 前由 canonical architecture guard 阻断，错误 `iOS build number drift: canonical=29 project=28`。Linux installable、视频、截图、trace、HTML report 均未生成。
- macOS job `101177474366`: SUCCESS；canonical package、notarize/staple、packaged Playwright journey 均成功。
- Windows job `101177474512`: SUCCESS；canonical package 与 packaged Playwright journey 成功。
- aggregate job `101180854619`: FAILURE。

因此 desktop required packaged gate 不满足，不得创建测试版本。

## 消息合同验收

Messaging Product Gate run `33920502888`: **SUCCESS**。

- Electron Messenger contract `101177474102`: SUCCESS
- Rust self-hosted product `101177474454`: SUCCESS

该结果仅作为源码/产品合同旁证，不替代 packaged simulated-user gate。

## Native/mobile 验收

Native mobile quality gate run `33920502967`: **FAILURE**。

- Android `101177474424`: SUCCESS；debug package + Pixel 7 emulator Compose simulated-user tests 通过。
- iOS `101177474816`: FAILURE；`testAccountSettingsAndMessagingFlow()` 期望 `Messenger`，实际 `Messaging unavailable`，断言位置 `mobile/ios/FabushiUITests/FabushiUITests.swift:97`；5 tests, 1 failure。
- aggregate `101181766179`: FAILURE。

## 证据验收

macOS/Windows diagnostics 提供 Playwright video/trace/screenshot/runtime logs，Android 提供 APK、HTML/XML/PB 测试报告和 per-test logcat，iOS 提供 xcresult。但是整体证据合同仍不满足：

- Linux required packaged path 在生成证据前失败；
- 通用 Playwright screenshot 策略为 failure-only，并非每个有意义步骤 always capture；
- 已观察到的完整 desktop video 属于 Grok visual-evidence journey，不是 OWNERSHIP-001 的单一完整消息 ownership journey；
- artifact 内部文件名未按要求包含 exact SHA/platform/run/job/journey/time；
- Android/iOS artifact retention 是 14 天，不是 90 天目标。

## 验收决定

本轮 **不允许** 创建 test tag/pre-release/release assets；**不允许** 交给代码审查组做“视频证据通过”复核；**不允许** 进入正式发布。

唯一后续是由有权限的执行/配置任务修复 canonical iOS build-number 一致性与 iOS messaging simulated-user failure，并在需要时补齐证据 workflow 契约；完成独立代码审查和受保护 main 合并后，再从新的 accepted-main SHA 发起全新的测试发布验收。