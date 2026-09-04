# PR #2320 R2 repair management / handoff — TFI

- Project: `FAB-P0001 / TFI`
- Branch: `arch/p0-recovery-20260904`
- Repair content commit: `a116f63b9d7d1f89422069605caebbb8475f0567`
- PR: `#2320` open/unmerged
- R2 rejected head: `a5ce2e522cf124910c6627c72a646513b90960fa`
- Historical review: `REVIEW-REJECTED`, id `5113492839`; #2321 history is immutable for this repair.
- Status: `ARCHITECTURE REPAIR WRITTEN; RE-REVIEW REQUIRED; EXECUTION BLOCKED`

## Management synchronization
WBS, milestones, acceptance, risk/dependencies and changelog now use the same dependency rule: a prerequisite is complete only after accepted contract + independent REVIEW-PASS + protected canonical merge + required CI + exact accepted-main installable/packaged E2E and Release evidence. Contract-only prework is permitted only where the task says so and cannot be submitted/accepted as completion.

TFI-M7 additionally carries the strict fallback security predicate and explicit execution/code-review/test-release ownership. Required exact-main test journeys include semantic available+allowed, available-but-denied, genuine unavailability fallback, approval deny/expire, account/pairing/control negatives, target/session/client/generation stale/revoked, MiniApp/install allow/disallow, audit/correlation, ambient privacy ignore and restart continuity.

## Next action
Independent code-review group: resolve the latest live PR #2320 head after this write-back, review the real diff and preserved R2 evidence, and issue a new verdict. No execution authorization exists unless that new verdict is `REVIEW-PASS`.