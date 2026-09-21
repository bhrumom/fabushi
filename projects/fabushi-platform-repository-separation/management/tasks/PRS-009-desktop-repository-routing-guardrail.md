# PRS-009 — Cross-repository routing and Spec-first guardrail

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-009`
- Source requirement: `PRS-REQ-012`
- Status: `passed`
- Started: `2026-09-21`
- Updated: `2026-09-21`
- Branch: `governance/prs-009-cross-repo-routing-followup`
- Source baseline: `2239369eae0161b271b8a0af2ea488f4d5d72167`

## Objective

Prevent AI/developer work from continuing in the wrong repository after the platform split, and establish Spec-first development instructions in every target repository.

## In scope

- Complete routing table in legacy `bhrumom/fabushi/AGENTS.md`.
- Core, CLI, Web, Desktop, Android, iOS, WeChat, Chrome Extension, Backend, Forum, Commerce, Marketplace, Governance, and the existing userscript repository.
- Root `AGENTS.md` + durable Spec-first policy/template in each target repository.
- Fail-closed repository identity and missing-Spec behavior.

## Out of scope

- Removing legacy product files from `bhrumom/fabushi`.
- Declaring all PRS production cutover/release gates complete.
- Product feature changes.
- Application builds or behavioral testing for this documentation/governance-only task.

## Acceptance criteria

1. Legacy root `AGENTS.md` lists every canonical target and routes product work away from `bhrumom/fabushi`.
2. Mobile (Android/iOS) and CLI are explicit, not implied.
3. Every listed target repository has a root `AGENTS.md` defining repository ownership and **No Spec, No Code**.
4. Every target repository has `docs/specs/spec-first-ai-development.md` and `docs/specs/SPEC_TEMPLATE.md`.
5. Desktop retains the previously merged Spec-first policy.
6. Target repo instructions require repository identity verification, Spec discovery/creation, implementation from the durable Spec, and requirement-to-evidence compliance review.
7. Legacy-source PR and target-repository PRs/commits are merged/read back from canonical `main`, or any blocked target is explicitly recorded.

## Verification

- GitHub API/readback for every target repository and root `AGENTS.md`.
- File readback for each target repository's Spec policy/template.
- PR/merge/main evidence.
- No application build/test required because this task changes governance/documentation only.

## Evidence

- Legacy source initial Desktop-only PR: #2723 -> merge `cb53b46ac606dfb54063b0a8215b290ddadb65c6`.
- Legacy source full-routing follow-up PR: #2724 -> merge `f1033a095bba7cf909fa212a6e8b7f2a099ae821`.
- Target repository merges:
- Desktop: `bhrumom/fabushi-desktop` PR #15 -> merge `ba0eb705665a7d938f19ea334208cc941d7c23b7`
- Core: `bhrumom/fabushi-platform-core` PR #1 -> merge `7e24aa179a44a206eceb722e650a1db6d5bb1f59`
- CLI: `bhrumom/fabushi-cli` PR #1 -> merge `2ee9e9853f10c0813a9abbaccf7bf9dc0e84bdd1`
- Web: `bhrumom/fabushi-web` PR #1 -> merge `c481dea9e2624a4903fe68e22e22760a47ef7727`
- Android: `bhrumom/fabushi-android` PR #1 -> merge `59f6fc8885ce1cb8d1ad4fc5d4ab36f690fb99a2`
- iOS: `bhrumom/fabushi-ios` PR #1 -> merge `d5ec44c14810de173f3584d1e72b067e8cd5fce2`
- WeChat: `bhrumom/fabushi-wechat` PR #1 -> merge `50fc470ed524818dabe75b4882cf8db77df21624`
- Chrome Extension: `bhrumom/fabushi-chrome-extension` PR #14 -> merge `a4a8fc2ef40bfe30afdad73672b434e386ac06a8`
- Backend: `bhrumom/fabushi-backend` PR #3 -> merge `5448c51a462e0e0cd118cc63cac5a8fc06cc4b66`
- Forum: `bhrumom/fabushi-forum` PR #1 -> merge `764b4eb45ffa5c3e9f2bcbc44023c2117c7ae946`
- Commerce: `bhrumom/fabushi-commerce` PR #1 -> merge `2554e20c67db58cf118a7e018657062a2bafffc3`
- Marketplace: `bhrumom/fabushi-marketplace` PR #1 -> merge `9090a933b70e8ab3c4f63a628827fb42ec81a29d`
- Governance: `bhrumom/fabushi-governance` PR #1 -> merge `b6d3d1b5bb066054198b70a373ffbf6473741ed6`
- Userscript: `bhrumom/fabushi-chatgpt-auto-confirm-userscript` PR #56 -> merge `68cd991578202ee25a1a0b9d92087429e5279d9d`

## Next action

Closed: #2724 merged through the protected merge queue; canonical `main` readback confirms the full routing table. All target repositories were read back with root `AGENTS.md`, `docs/specs/spec-first-ai-development.md`, and `docs/specs/SPEC_TEMPLATE.md`.
