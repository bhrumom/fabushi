# Code review evidence — PR #2320

- Project: `FAB-P0001/TFI`
- Program: `FAB-ARCH-P0-20260904`
- Reviewed PR: `bhrumom/fabushi#2320`
- Reviewed architecture head: `21ee56892db48925fe863320a1cd68b51c4596cd`
- Canonical base: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- M6 implementation input inspected: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Review date: `2026-09-04 +08:00`
- Verdict: `REVIEW-REJECTED`

## Scope verification

The PR changed only `projects/telegram-fabushi-integration/**`, `projects/mahayana-sovereign-runtime/**`, and `projects/grok-bot-fabushi-integration/**`. No application source, root `AGENTS.md`, `projects/PORTFOLIO.json`, or `.github/workflows/**` change was present in the reviewed head.

## Blocking findings

1. The nine new TFI atomic task files exist, but they are not uniformly self-contained execution contracts. Every task must explicitly carry stable Task ID, objective, exact files/modules, dependency state, parallel condition, implementation steps, in/out boundaries, and explicit unit/contract/integration/E2E/security/performance acceptance (`N/A` with reason where not applicable), plus branch/commit/PR/CI/evidence/status/changelog write-back contract. The shared WBS/release documents do not substitute for the authoritative task file.
2. Concrete module paths are missing from `TFI-M6-P0-003`, `TFI-M6-P0-004`, and `TFI-M6-P0-005`; several TFI tasks also omit explicit parallel/boundary/handoff/test-category fields.
3. The M6 priority direction is valid but the task text must reconcile to the current implementation head. At `9e88a2e9...`, `RespondCommunityJoin` still constructs `participant_event` with `approved && <Option<_>>`, which is a real compile blocker, and `CreateConversation` still projects directly to `UpsertConversation`, so `TFI-M6-P0-001` correctly remains first. Conversely, no-Community `RequestCommunityJoin` already returns `CommunityNotFound` at this head; that requirement must be stated as a regression guard rather than an unresolved current defect. Admission policy remains incomplete and must cover public/private/invite/join-request modes with negative tests.
4. `TFI-M7-P0-001` gates group Bot behavior on `MSR-210` and `GBF-508` but not the MSR capability policy plane. Since the task requires approval/tool permission fail-closed semantics, require `MSR-211 REVIEW-PASS` explicitly or make it an unambiguous transitive hard dependency through `GBF-508`.
5. The cross-project packaged evidence contract mentions video/screenshots/trace/report/logs and pass/fail retention, but the execution/test handoff must also bind evidence to exact canonical-main SHA, app version, platform, workflow run/job, journey/test ID and timestamp, use an `always()`-equivalent upload path, and apply the repository retention rule from root `AGENTS.md`.
6. There were no GitHub check-runs on the inspected M6 head, so no CI success may be inferred from branch presence or source review.

## Required repair before re-review

Normalize all nine TFI task files to the repository atomic-task schema; pin exact current modules and dependency statuses; correct the M6 current-state wording; add the MSR-211 capability gate to group-Bot closure; and make the root post-main evidence requirements explicit in the task/release handoff. Do not advance WBS/acceptance status until a fresh real-diff review passes.
