# ADR-0006: Historical Grok Fusion Branches Are Read-Only Audit Inputs

Status: Accepted for release closure — 2026-08-22

## Context

FAB-P0004 used `grok-bot-latest-source-fusion` and `grok-bot-0.16-source-fusion` as historical source inputs for capability inventory, behavior comparison and provenance analysis. They diverged from `main`; capability-level replay/reimplementation was explicitly chosen instead of wholesale branch replacement. The historical Grok 0.20 production snapshot remains `PROVENANCE_BLOCKED`/reference-only.

Pinned audit refs from M1:

- `grok-bot-latest-source-fusion`: `7174a70567ae98ef534b0eebcbe66935f1471cc1`
- `grok-bot-0.16-source-fusion`: `a8bd854b512a3eaf20be9518767ab593724d67dc`
- historical comparison merge-base: `fb3ac82da93de473a372f489cf8ecb7f348c87d0`

## Decision

1. `main` is the only build, runtime and release authority for Fabushi/Mahayana.
2. The two Grok fusion branches may be retained for read-only audit/reproducibility purposes; they are not development bases, release inputs or recovery branches.
3. No CI, packaging, deployment or release workflow may directly check out or merge either historical branch.
4. Wholesale merge/overwrite from a historical Grok branch remains forbidden. A future capability discovered there must go through a new project/task, provenance decision, clean implementation/replay, tests and normal protected-main review.
5. Retention does not change license status. Any historical source classified `PROVENANCE_BLOCKED` remains reference-only.
6. Destructive deletion is not required for closure because it would reduce auditability without improving runtime isolation; authority is removed by governance and machine checks instead.

## Consequences

- Source history remains reproducible.
- Production cannot silently regress to an old Grok-derived runtime tree.
- Fabushi ownership is expressed through current `main` code, contracts, tests and release artifacts rather than branch renaming.
