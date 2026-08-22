# GBF-803 — 正式发布

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-803
- Stage: M8-release-closure
- Objective: 基于通过 GBF-801/802 的 canonical main commit 建立不可变版本 tag，执行现有 Native Electron application release，并产生三桌面平台、Android、iOS、SHA256SUMS 与 GitHub Release 证据。
- Requirements: GBR-007, GBR-010.
- Dependencies: GBF-801, GBF-802; M2..M7 RELEASED.
- Status: NOT_STARTED
- Branch: `gbf/m8-release-closure-20260822`
- Started/Updated: 2026-08-22 19:52+08

## Acceptance
- [ ] release tag 精确指向 canonical main commit；不从 feature branch 发布。
- [ ] tagged commit 的 `CI result`, `Electron desktop result`, `Native mobile result` 全部 success。
- [ ] release workflow Electron smoke success。
- [ ] macOS/Windows/Linux packages success。
- [ ] signed Android APK/AAB success。
- [ ] signed iOS IPA success。
- [ ] SHA256SUMS generated and immutable GitHub Release created。
- [ ] post-release smoke/evidence recorded。

## Blocker policy
Signing/store credentials若缺失必须记录真实 blocker；禁止跳过签名 job 后宣称 RELEASED。
