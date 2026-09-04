# ARCHITECTURE REPAIR — PR #2320 R2 — GBF

- Project: `FAB-P0004 / GBF`
- Program: `FAB-ARCH-P0-20260904`
- Branch: `arch/p0-recovery-20260904`
- Base: canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- R2 reviewed/rejected head: `a5ce2e522cf124910c6627c72a646513b90960fa`
- R2 review: `REVIEW-REJECTED`, review id `5113492839`
- Review records: PR `#2321@a9e965a9a4dfd47baeb72742a29e6ef3eda402c2`, not modified
- R2 repair content commit/head before evidence write-back: `a116f63b9d7d1f89422069605caebbb8475f0567`
- Governance PR: `#2320`, open/unmerged
- Known regression truth: Actions run `33876067936` is `failure`; this repair does not report it green
- Owner: Architecture project group; next owner: independent code-review group

## R2 repair
- GBF-508 now task-locally requires `MSR-210`, `MSR-211`, `GBF-409`, and `GBF-411` **each** to complete contract acceptance + independent `REVIEW-PASS` + protected canonical-main merge + required CI + exact accepted-main installable/packaged E2E and Release evidence. Downstream GBF-508 evidence cannot substitute for unfinished prerequisite evidence.
- Current truth is preserved: MSR-201/MSR-202 `in-progress`; GBF-409/GBF-411 `IN_PROGRESS`; therefore MSR-210/MSR-211/GBF-508 remain BLOCKED where applicable.
- GBF-508 fallback requires genuine semantic unavailability, same-account paired device, control enabled, current/non-revoked target/session/client/generation, granted unexpired approval, explicit MiniApp/install permission, and fully audited/correlated action. Deny/expire/stale/revoke/install-disallow/available-but-denied/missing-correlation all fail closed.

## GBF changed files in repair content commit
- `management/tasks/GBF-508-group-bot-behavior-capability-routing.md`
- `management/09-2026-09-04-P0-WBS.md`
- `management/10-2026-09-04-P0-acceptance-risk-changelog.md`
- `management/11-2026-09-04-P0-里程碑.md`
- `management/12-2026-09-04-P0-验收追踪.md`
- `management/13-2026-09-04-P0-风险与依赖.md`
- `management/14-2026-09-04-P0-变更日志.md`

## Claims / handoff
Governance-only `projects/**`; no local build/test; no source/CI/workflow/root-AGENTS modification; no protected merge/required-CI/package/Release success claimed. Run `33876067936` remains failure. Independent code review must inspect the latest live PR #2320 head after evidence write-back; only a new `REVIEW-PASS` may authorize execution.