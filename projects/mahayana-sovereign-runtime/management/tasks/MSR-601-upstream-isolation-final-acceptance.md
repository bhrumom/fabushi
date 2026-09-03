# MSR-601 — Upstream isolation and final acceptance

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-601
- **Status:** in-progress
- **Started:** 2026-08-22T16:57:00+08:00
- **Updated:** 2026-08-23T10:34:00+08:00
- **Completed:** null

## Objective
Prove Mahayana's default product path is Fabushi-owned and can operate without vendor product crates while preserving optional audited compatibility adapters behind explicit boundaries.

## Source requirements
MSR-R01 through MSR-R08; final Definition of Done. FCM-007 discovered a concrete default-graph regression while validating Telegram convergence PR #2038 against canonical `main`: `mahayana-cli -> codex-core-plugins` and `mahayana-cli -> codex-tui` remained reachable by default.

## In scope
Dependency/source audit; default-feature isolation; adapter-disable build/test gate; provenance/license closure; project acceptance/evidence closure. The current repair replaces the two narrow CLI implementation dependencies with Mahayana-owned compatibility packages while preserving the existing CLI call contracts.

## Out of scope
Deleting audited optional compatibility source before all downstream migration consumers are removed; changing Telegram behavior while resolving this Mahayana-owned default-graph blocker.

## Dependencies
MSR-501 and all required prior MSR tasks. This blocker must be repaired before FCM-007 can merge Telegram PR #2038 because `Mahayana fast checks` correctly fails the merge ref.

## Acceptance criteria
1. Default Mahayana native product graph contains no Codex/xAI product crates.
2. `mahayana-cli` no longer reaches vendor `codex-core-plugins` or `codex-tui` in its default dependency closure.
3. Mahayana-owned replacements preserve plugin archive extraction and interactive composer/terminal contracts used by the CLI.
4. Source-boundary and relevant Mahayana fast checks pass on the exact repair head and merge group.
5. Protected merge lands the repair on canonical `main`, which is re-read before Telegram convergence resumes.
6. Full MSR final-acceptance closure remains truthful and is not claimed until the broader MSR-601 criteria are satisfied.

## Verification
`check-mahayana-source-boundary.py`; Mahayana fast checks; targeted Rust tests for the new compatibility packages; protected merge; canonical-main re-read.

## Branch / commit / PR
Branch: `fix/msr-601-cli-vendor-boundary-20260823`
Commit: pending
PR: pending

## Implementation summary
The repair will keep optional audited Codex adapters behind explicit compatibility features, but replace the two default CLI implementation dependencies with first-party Mahayana packages. Existing `codex_tui` / `codex_core_plugins` call-site names are treated only as source-level compatibility aliases; Cargo resolves them to Mahayana-owned packages, so the default package graph is vendor-independent without forcing a broad CLI rewrite during the blocker fix.

## Evidence
- Telegram #2038 merge-ref `1e34bb9f8eb23fa0f4cf5d17548f383550d3d287` failed Mahayana fast checks at source-boundary verification.
- Failure: `mahayana-cli -> codex-core-plugins` and `mahayana-cli -> codex-tui` remained in the default native dependency graph.
- Canonical `main` at discovery: `012569a9ad62925ac33311043439787d45072e2a`.

## Blockers / risks
Compatibility packages must preserve archive traversal protections and terminal input behavior; the repair must not weaken the source-boundary checker or simply allow-list vendor crates.

## Next action
Implement the two Mahayana-owned compatibility packages, update the CLI dependency resolution, regenerate the workspace lockfile through GitHub Actions if required, and pass the exact-head/merge-group gates before resuming #2038.
