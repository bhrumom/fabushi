# 2026-09-01 — 统一移动端逻辑 UI / 1.1.0 全平台交付变更

- Project: `FAB-P0001 / TFI`
- Release train: `M11-MOBILE-001`
- Version: `1.1.0`

## Summary

统一移动端逻辑 UI 的剩余实现、iOS/Android 收尾修复、版本元数据与全平台交付链路已完成。桌面发布使用当前 main 的 recovery tag；移动端二进制使用紧邻父提交的产品源码基线，因该父提交到当前 main 只有发布 workflow 变化。

## Change set

- #2248–#2251: unified mobile logic UI implementation.
- #2252: version metadata convergence.
- #2253–#2260: iOS bridge/accessibility/profile/navigation fixes.
- #2261: Android FileProvider release merge fix.
- #2262: immutable same-version desktop release recovery.

## Verification

- Current main: `3f7cddc0bc09802d9a3d142cab7f9a56c573c07c`.
- Product source: `82ddb78653ecdc47c95bf1a372389adff9f24d09`.
- CI `33436781726`, native mobile `33436781683`, Electron `33436781694`, governance `33436781731`, post-main `33437994689`, Worker `33436811350`, Pay `33436811361`: SUCCESS.
- Desktop Release: `desktop-1.1.0-3f7cddc0bc09`.
- Android Release: `android-v1.1.0-262432005`.
- Apple Release: `apple-v1.1.0-2026.8.3133`.

## Scope note

This change closes the UI/release train, not the full M11 cross-device interoperability milestone. ACT-006 remains open for shared-Core messaging, push sync, and background recovery proof.