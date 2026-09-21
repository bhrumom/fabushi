# PRS-009 — Cross-repository routing and Spec-first guardrail

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-009`
- Source requirement: `PRS-REQ-012`
- Status: `implemented`
- Started: `2026-09-21`
- Updated: `2026-09-21`
- Branch: `governance/prs-009-desktop-repo-routing-guardrail`
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

- Legacy source PR: #2723.
- Target repositories: listed in PRS-REQ-012.
- Final per-repository PR/merge/main evidence: to be recorded after completion.

## Next action

Finish all target-repository governance changes, merge them, then update PRS-009 to `passed` with canonical-main readback evidence.
