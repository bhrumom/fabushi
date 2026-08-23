# FCM-009 — Incremental build & test efficiency

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-009
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23
- **Branch:** `project/fcm-009-build-test-efficiency`

## Objective

把 Fabushi 全平台 GitHub Actions 构建改造成可跨运行复用上一轮缓存与中间产物的增量体系，并把 PR 快速 CI 与 `main` 合并后的重型安装包/Debug/E2E 工作彻底分层。

## Source requirements

- `source/2026-08-23-build-test-efficiency.md`
- FCM-R008 ~ FCM-R012

## In scope

- PR CI：仅快速静态/格式/类型/契约/必要单元级检查；禁止 E2E、安装包构建、Debug 安装包构建。
- `main` push：按影响域运行 Electron macOS/Windows/Linux、Android、iOS 的安装包/Debug 构建和 E2E。
- Node/npm/pnpm、Cargo/Rust、Gradle/Android、Xcode/iOS、Electron/native host 的跨 run 缓存。
- 内容寻址缓存键、restore-key fallback、缓存版本化与失效规则。
- 同一 run 内 artifact handoff + 跨 run cache reuse，避免重复编译 native host/JNI/staticlib/renderer。
- 缓存命中率、cold/warm build 时间与节省比例观测。

## Out of scope

- self-hosted runners；
- 本地开发机重型 build/test；
- 牺牲 required safety gates、签名、notarization、merge queue 或 release-source safety；
- 把构建产物缓存当作永久 release artifact。

## Atomic work

1. `FCM-009.1` 建立 PR-fast / post-main-heavy 事件分层。
2. `FCM-009.2` Electron 三平台缓存与 native host/renderer 复用。
3. `FCM-009.3` Android Gradle/JNI/SDK/AVD 增量缓存。
4. `FCM-009.4` iOS Cargo/staticlib/DerivedData/SwiftPM 增量缓存。
5. `FCM-009.5` Node dependency/build-cache 分层。
6. `FCM-009.6` main 影响域选择：只构建/测试受影响平台。
7. `FCM-009.7` 缓存 telemetry：hit/miss、cold/warm duration、节省率。
8. `FCM-009.8` governance contract：PR 不得出现 E2E/installer/debug package heavy jobs；main 才允许。
9. `FCM-009.9` 真实连续两轮相同平台变更验证 warm-cache 加速。

## Acceptance criteria

- PR workflow 不启动 Playwright/Android instrumentation/iOS UI E2E、Electron installer、Android APK/AAB debug package、iOS app/archive 重型构建。
- `main` push 对受影响平台自动运行安装包 + Debug 包 + E2E；不受影响平台跳过。
- 同一工具链/锁文件下第二轮小改动能恢复上一轮 cache；只重建失效子图。
- Rust、Gradle、Node、Xcode/Electron 关键缓存有显式版本和失效输入，不能使用无限宽泛 key。
- cache miss 能完全回退为正确 clean build。
- 至少记录一组 cold vs warm Actions run 证据；目标 warm build 墙钟时间较 cold build 降低 >= 50%，若平台限制未达标则保留实测并继续优化，不伪造通过。
- 所有 workflow/governance 修改通过 protected PR/merge queue 和项目治理检查。

## Evidence required

PR、commit、Actions run/job、cache hit/miss summary、cold/warm duration、构建产物、E2E report、post-merge canonical-main verification。

## Risks

错误缓存导致陈旧二进制；缓存键过细导致低命中；过宽导致污染；GitHub cache 容量/驱逐；Xcode/SDK 版本漂移；main 重型矩阵成本过高。

## Next action

审计现有 workflows 的事件触发与缓存边界，先落 PR-fast / main-heavy 分层，再逐平台优化缓存。
