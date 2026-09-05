# TFI-M6-MAINSAFE-001-TEST-RELEASE-001

- Project: `FAB-P0001 / TFI`
- Role: test-release project group
- Date: 2026-09-05
- Status: `BLOCKED / REQUIRED-MAINSAFE-POST-MAIN-PREREQUISITES-NOT-SATISFIED`
- Product PR: `#2345`
- Reviewed exact product head: `9c46c1d8f030be390995cc78f321aac0d96b7f44`
- Canonical base read before queue: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Canonical merge/readback SHA: `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`
- Independent review provenance: `REVIEW-PASS-VERSION-EXACT-HEAD-CHECKOUT-001`, records-only PR `#2346` (read as OPEN; not treated as product implementation)

## Phase 1 — protected canonical-main merge gate

PASS.

- #2345 remained exact base/head with no product-head drift before queue entry.
- Main ruleset `main-merge-queue` was read active with `SQUASH`, `ALLGREEN`, no bypass actors, and required status `CI result`.
- Auto-merge was enabled for #2345; no direct merge, force push, rebase, retarget, or special bypass was used.
- Queue ref: `gh-readonly-queue/main/pr-2345-dbf22b467d35c8af2a074896c355a41993c8c191`.
- Merge-group/synthetic SHA: `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`.
- Merge-group run: `33939126976`, attempt 1, event `merge_group`, conclusion `success`.
- Canonical-version job: `101232897597`, conclusion `success`. Raw log proves checkout and `git rev-parse HEAD` both equal the expected group SHA before the unchanged canonical script runs: `event=merge_group expected_head=63e49b87d1ca5ad64d988e73769bf4a4ed796a19 actual_head=63e49b87d1ca5ad64d988e73769bf4a4ed796a19`.
- Required same-run `CI result` job: `101233054947`, conclusion `success`; raw log records `version_contract_result=success` and the diff-selected aggregate dependencies as success.
- #2345 merged at `2026-09-05T02:29:10Z` as signed squash commit `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, parent `dbf22b467d35c8af2a074896c355a41993c8c191`.
- Canonical `main` was immediately re-read at exactly `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`.

Links:
- https://github.com/bhrumom/fabushi/pull/2345
- https://github.com/bhrumom/fabushi/actions/runs/33939126976
- https://github.com/bhrumom/fabushi/actions/runs/33939126976/job/101232897597
- https://github.com/bhrumom/fabushi/actions/runs/33939126976/job/101233054947

## Phase 2 — exact-main packaged test-release gate

BLOCKED before a compliant fresh test-release can be accepted.

The architecture freeze in records-only PR #2340 defines three separate prerequisites for a compliant post-main packaged acceptance:

1. `TFI-M6-MAINSAFE-001-IOS-FIXTURE-001`
2. `TFI-M6-MAINSAFE-001-EVIDENCE-CONTRACT-001`
3. `TFI-M6-MAINSAFE-001-EVIDENCE-JOURNEY-001`

All three were re-read from #2340 as `FROZEN / NOT_STARTED`. Direct canonical readback at exact main `63e49b87...` returned 404 for all three task paths, proving they have not landed in canonical main.

The exact-main automatic push workflows are allowed to finish and their real outcomes/artifacts are recorded as observational post-main evidence. They must not be promoted to compliant test-release acceptance because the frozen evidence contract/owned journey and deterministic iOS fixture have not been independently implemented, reviewed, protected-merged, and read back on canonical main.

This test-release group does not modify product source, tests, workflow/evidence plumbing, version configuration, or formal release state to fill those missing prerequisites.

## Open-source-first / reuse decision

No new implementation is introduced. The stage reuses the repository's existing merge queue, canonical exact-head guard, GitHub-hosted Electron/native workflows, cache layers, Playwright diagnostics, and existing packaged verification paths. Missing requirements are not reimplemented here because they are separately frozen work owned by later implementation/review rounds.

## Release / rollback

- No stable/formal release was created or modified by this test-release group.
- No test-release PASS candidate is declared.
- No product rollback/revert is executed: the protected merge itself passed its authorized gate; the blocker is downstream packaged-acceptance readiness, not an unreviewed product mutation.
- Retry is permitted only after the three frozen prerequisites above are independently implemented, reviewed, protected-merged, and canonical-main read back.
