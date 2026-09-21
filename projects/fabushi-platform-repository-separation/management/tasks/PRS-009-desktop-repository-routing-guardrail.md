# PRS-009 — Desktop repository routing guardrail

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

Prevent AI/developer work from continuing against legacy Desktop source in `bhrumom/fabushi` after Desktop ownership moved to `bhrumom/fabushi-desktop`.

## In scope

- Root `AGENTS.md` repository-identity/routing guardrail.
- Durable requirement/task/status/changelog traceability under PRS.
- Explicit fail-closed behavior for Desktop product tasks encountered in the old source repository.

## Out of scope

- Removing legacy Desktop files from `bhrumom/fabushi`.
- Declaring all PRS production cutover/release gates complete.
- Modifying Desktop product code in either repository.
- Running application builds or behavioral tests.

## Acceptance criteria

1. Root `AGENTS.md` names `bhrumom/fabushi-desktop` as canonical for Desktop product development.
2. It explicitly prohibits Desktop product implementation in `bhrumom/fabushi`, even when legacy Desktop files still exist.
3. It requires repository identity verification and switching repositories before Desktop implementation.
4. It requires reading `bhrumom/fabushi-desktop/AGENTS.md` and applicable Specs after switching.
5. It preserves an explicit exception for source-repository migration/governance/history work.
6. The change is merged and read back from canonical `main`.

## Verification

- GitHub API/readback of both repositories.
- PR diff review.
- Canonical-main readback of root `AGENTS.md`.
- No application build/test is required because this is governance/documentation only.

## Evidence

- Target repo verified: `https://github.com/bhrumom/fabushi-desktop`.
- Branch: `governance/prs-009-desktop-repo-routing-guardrail`.
- PR / merge / canonical-main evidence: pending.

## Next action

Open PR, merge through repository governance, then update this task to `passed` with PR/merge/main-readback evidence.
