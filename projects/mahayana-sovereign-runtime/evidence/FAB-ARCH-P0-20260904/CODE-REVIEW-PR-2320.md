# Code review evidence — PR #2320

- Project: `FAB-P0005/MSR`
- Program: `FAB-ARCH-P0-20260904`
- Reviewed PR: `bhrumom/fabushi#2320`
- Reviewed architecture head: `21ee56892db48925fe863320a1cd68b51c4596cd`
- Canonical base: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Review date: `2026-09-04 +08:00`
- Verdict: `REVIEW-REJECTED`

## Positive findings

- Project identity remains `FAB-P0005/MSR`; no duplicate project was created.
- `ADR-0003` consistently defines MSR as the exclusive Bot execution/session owner and the `1 Bot : 1 durable Mahayana session` invariant.
- Pinned upstream revisions are real: `openai/codex@8e85265c39176b6bd498242a33d7b0f9b4b98303` and `xai-org/grok-build@72a61251fcffb464bcc687aeb5a998e5a98ec0c9`; both root LICENSE files are Apache-2.0. Codex has a root NOTICE that must be preserved when applicable.
- The testing/security addendum separates Bot identity from device authority and requires policy/approval/audit for devices and MiniApps.

## Blocking findings

1. `MSR-107`, `MSR-210`, and `MSR-211` are not complete atomic execution contracts. Normalize each file to explicitly contain exact files/modules, dependencies with current state, parallel condition, implementation steps, boundaries, and unit/contract/integration/E2E/security/performance acceptance (`N/A` with reason if not applicable), plus branch/commit/PR/CI/evidence/status/changelog write-back.
2. `MSR-210` depends on `MSR-201`; `MSR-211` depends on `MSR-202` and reuses GBF contracts. Canonical `MSR-201` and `MSR-202` are still `in-progress` with commit/PR/CI evidence pending. Treating them merely as existing contracts is insufficient: mark them as hard prerequisites or explicitly scope/duplicate the minimum required contract into the new tasks with acceptance evidence.
3. `MSR-211` also relies on GBF device/App-MCP capabilities. Canonical `GBF-409` and `GBF-411` are `IN_PROGRESS` and their GitHub CI/E2E/exact-main release evidence is pending. Closure of MSR capability routing cannot assume those dependencies are satisfied.
4. Packaged evidence handoff must carry the full root `AGENTS.md` canonical evidence identity: exact main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, `always()`-equivalent pass/fail upload, and repository retention target/constraint. The current new docs require video/screenshots/trace/report/logs and pass/fail retention but do not make all identity/retention fields executable in each task.
5. Upstream adaptation tasks must record exact-file provenance when code is actually adapted, and preserve required LICENSE/NOTICE obligations. Architecture-level revision/license inventory alone cannot close implementation provenance.

## Required repair before re-review

Make unfinished MSR-201/MSR-202 and GBF-409/411 explicit hard gates where their contracts are required; normalize MSR-107/210/211 into self-contained task contracts; add exact-file provenance/NOTICE requirements and complete packaged evidence identity/retention handoff. Do not mark MSR-210/211 review-passed until those prerequisites and task records are verifiable from real diffs and CI evidence.
