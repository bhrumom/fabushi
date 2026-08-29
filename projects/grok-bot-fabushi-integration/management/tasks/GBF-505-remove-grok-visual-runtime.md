# GBF-505 — 移除生产 Grok 视觉/runtime 依赖

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-505
- Stage: M5
- Objective: 移除生产 Grok/Cursor/OpenMaus 视觉/runtime 与上游压缩 renderer 依赖，保留 observable parity，但生产实现完全由 Fabushi-owned source 构建。
- Requirement: GBR-006, GBR-008；follow-up source `source/2026-08-28-remove-upstream-compiled-runtime.md`。
- Dependencies: GBF-501..504.
- Status: IN_PROGRESS
- Branch: `gbf/505-fabushi-owned-avatar-runtime`
- PR: #2202
- Started: 2026-08-22 17:58+08
- Reopened/Updated: 2026-08-28 18:48+08

## Acceptance
- [x] production BotMark 不依赖 Grok/Cursor/OpenMaus runtime bundle 或 vendored mascot implementation。
- [x] 删除 `frontend/apps/web/src/app/host/openmaus-cursor-avatar.tsx`。
- [x] 新增 Fabushi-owned `fabushi-avatar-runtime.tsx`，实现 procedural SVG、gradient、Agent state motion、gaze、spin/bounce/burst、visibility pause、reduced motion。
- [x] `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime` 为单一 production avatar source chain。
- [x] CI guard 改为 fail closed，禁止 OpenMaus/CursorAvatar/Grok renderer bundle/checksum-pinned renderer 运行依赖回流。
- [ ] GitHub frontend/CI checks 通过。
- [ ] protected merge + canonical-main readback。
- [ ] post-main packaged Electron E2E visual evidence 通过。
- [ ] verified Release evidence 完成。

## Verification

- `.github/scripts/assert-bot-mark-motion.py`
- frontend TypeScript typecheck + production web build
- Electron Feature Host contract
- packaged Electron BotMark/Grok-parity visual journeys
- repository source/dependency audit

## Evidence

`evidence/GBF-505/README.md`.

## Current result

本轮已将最后一条明确的 production vendored avatar 实现替换为 Fabushi-owned source；历史 Grok/OpenMaus 资料只允许留在 project evidence/reference，不允许成为 production runtime input。PR #2202 已打开；首轮 Host fast E2E 暴露 SVG JSX `transformOrigin` 类型问题后已修复。任务在 CI、protected-main merge、post-main package/E2E/Release 完成前保持 `IN_PROGRESS`。
