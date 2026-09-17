# GBF-806 evidence

## Scope

This evidence set covers the clean-room integration of observable Bot single-conversation behavior from the local ChatGPT.dmg into the current Fabushi Electron, native iOS, native Android and Mahayana architecture.

Historical Flutter client work is explicitly out of scope. No private ChatGPT.app source, app.asar content, brand asset or binary is vendored.

## Source and implementation records

- Source analysis: projects/grok-bot-fabushi-integration/source/2026-09-09-chatgpt-dmg-bot-session-parity.md
- Task record: projects/grok-bot-fabushi-integration/management/tasks/GBF-806-chatgpt-dmg-bot-session-parity.md
- Desktop implementation: desktop/src/bot-conversation-view.tsx and desktop/src/messaging-shell-v2.tsx
- Native implementation: mobile/android/app/src/main/java/com/ombhrum/fabushi/MobileBotViewModel.kt and mobile/ios/Fabushi/GrokMobileShell.swift

## Current verification

- Desktop renderer typecheck/build: passed in the isolated worktree.
- Android compileDebugKotlin: passed in the isolated worktree; existing warnings remain.
- iOS project generation and test: pending dedicated CI workflow.
- GitHub CI, protected-main verification, packaged/simulated-user E2E, visual artifacts and exact-SHA Release: pending.

## Acceptance state

The implementation is recorded as IMPLEMENTED only. This directory must be updated with CI run URLs, screenshots, videos, traces, native reports and release linkage before GBF-806 can advance to TESTED, E2E_VERIFIED or RELEASED.
