# ARCHITECTURE REPAIR — PR #2320 R2 — MSR

- Project: `FAB-P0005 / MSR`
- Program: `FAB-ARCH-P0-20260904`
- Branch: `arch/p0-recovery-20260904`
- Base: canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- R2 reviewed/rejected head: `a5ce2e522cf124910c6627c72a646513b90960fa`
- R2 review: `REVIEW-REJECTED`, review id `5113492839`
- Review records: PR `#2321@a9e965a9a4dfd47baeb72742a29e6ef3eda402c2`, not modified
- R2 repair content commit/head before evidence write-back: `a116f63b9d7d1f89422069605caebbb8475f0567`
- Governance PR: `#2320`, open/unmerged
- Owner: Architecture project group; next owner: independent code-review group

## R2 repair
- MSR-210 now requires `MSR-201` itself to have contract acceptance + independent `REVIEW-PASS` + protected canonical-main merge + required CI + exact accepted-main installable/packaged E2E and Release evidence. MSR-201 remains `in-progress`; MSR-210 remains BLOCKED.
- MSR-211 now requires that same complete lineage **individually** for `MSR-202`, `MSR-210`, `GBF-409`, and `GBF-411`. MSR-202 remains `in-progress`; GBF-409/411 remain `IN_PROGRESS`; MSR-211 remains BLOCKED.
- MSR-202 is not a current MSR-210 hard prerequisite under the session-binding scope; if implementation crosses policy/approval scope, it must be added with the same full gate before editing.
- Blocked prework is contract-only; integration implementation cannot be submitted or accepted while dependencies are incomplete.

## MSR changed files in repair content commit
- `management/tasks/MSR-210-bot-durable-session-binding.md`
- `management/tasks/MSR-211-bot-capability-policy-plane.md`
- `management/09-2026-09-04-P0-WBS.md`
- `management/10-2026-09-04-P0-acceptance-risk-changelog.md`
- `management/11-2026-09-04-P0-里程碑.md`
- `management/12-2026-09-04-P0-验收追踪.md`
- `management/13-2026-09-04-P0-风险与依赖.md`
- `management/14-2026-09-04-P0-变更日志.md`

## Claims / handoff
Governance-only `projects/**`; no local build/test; no source/CI/workflow/root-AGENTS modification; no protected merge/CI/package/Release success claimed. Historical R2 rejection is preserved. Independent code review must inspect the latest live PR #2320 head after evidence write-back and issue a new verdict; only a new `REVIEW-PASS` may authorize execution.