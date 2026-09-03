# ADR-0003 — Immutable Global Portfolio Project Identifiers

- Status: Accepted
- Date: 2026-08-22
- Decision owners: repository-governance / repository-maintainers
- Task: FPG-004

## Context

Fabushi project folders historically used heterogeneous `project_id` values such as `FPG`, `MSR`, `FCM`, `FABUSHI-TELEGRAM-FUSION`, and `FABUSHI-GROK-BOT-FUSION`. Those values were useful as mnemonic namespaces but did not provide one globally ordered, immutable portfolio identity across projects.

As the number of independent initiatives grows, project routing, portfolio reporting, external control-plane synchronization, archive/merge history, and automation need a single identifier whose meaning is independent of project name, directory, task prefix, or product branding.

## Decision

Fabushi adopts a two-layer identity model:

1. **Canonical portfolio Project ID**: `FAB-P0001`, `FAB-P0002`, ... .
   - unique across the Fabushi portfolio;
   - immutable after allocation;
   - monotonically allocated from the high-water mark in `projects/PORTFOLIO.json`;
   - never reused, recycled, compacted, or reassigned.
2. **Project Key**: short stable mnemonic such as `TFI`, `FPG`, `FCM`, `GBF`, `MSR`.
   - used as the human-readable namespace for requirements, WBS tasks, milestones, risks, and other internal identifiers;
   - does not replace the global Project ID.
3. Previous project identifiers are retained as `legacy_project_ids` aliases for traceability and must not be reassigned.
4. `projects/PORTFOLIO.json` is the authoritative machine-readable allocation registry. Every canonical project `PROJECT.yaml` must mirror its registered `project_id`, `project_key`, `slug`, and authoritative path.
5. Pre-policy projects are backfilled by the timestamp of the first formal project-folder commit merged to canonical GitHub `main`.
6. New-project creation is serialized through the registry: a PR must allocate the current `next_sequence`, increment it, and create matching project metadata atomically.
7. CI compares the current registry to the target-branch registry and rejects mutation/removal of existing IDs, duplicate identities, malformed sequences, or registry/project-folder divergence.

## Initial allocation

| Project ID | Key | Project |
|---|---|---|
| FAB-P0001 | TFI | Telegram integration |
| FAB-P0002 | FPG | Project governance |
| FAB-P0003 | FCM | CI/CD & merge governance |
| FAB-P0004 | GBF | Grok Bot fusion |
| FAB-P0005 | MSR | Mahayana sovereign runtime |

Next allocation after migration: `FAB-P0006`.

## Alternatives considered

### A. Keep mnemonic strings as the only Project ID

Rejected. They are readable but not globally ordered, historically inconsistent, and easy to rename or collide as the portfolio grows.

### B. Encode product/team/date into the numeric ID

Rejected. Semantic IDs become unstable when ownership, branding, scope, or organizational structure changes. Stable surrogate identity should not carry mutable business meaning.

### C. Use UUID/ULID as the primary human project identifier

Rejected as the primary portfolio identifier because it is unnecessarily opaque for a repository-sized engineering portfolio. A monotonic zero-padded surrogate is easier to communicate and audit. UUIDs may still be used by external systems internally.

### D. Renumber projects after archive or consolidation to keep the sequence dense

Rejected. Renumbering destroys historical referential integrity. Density is less important than permanence.

## Consequences

### Positive

- Stable identity survives rename, archive, split, merge, or branding changes.
- Portfolio views and external systems can share one durable identifier.
- Project keys and task IDs remain human-friendly without carrying cross-project identity responsibility.
- Merge conflicts on `PORTFOLIO.json` deliberately serialize concurrent project creation and prevent duplicate allocation.

### Costs / tradeoffs

- Existing projects require a one-time migration and alias preservation.
- New project creation includes one additional registry edit.
- The numeric ID does not encode business meaning by design; users must consult the registry for project name/path.

## Migration and rollback

- Backfill all current canonical project folders in one governance change.
- Preserve every prior identifier under `legacy_project_ids`; do not rewrite historical PRs/commits/tasks.
- If the rollout must be reverted before merge, discard the branch. After merge, Project IDs are permanent; a future policy change must supersede this ADR without reassigning already-issued IDs.

## Verification

- `scripts/check-project-portfolio.py`
- `.github/workflows/project-portfolio-governance.yml`
- FPG-004 acceptance matrix/evidence
- Protected merge and post-merge canonical `main` verification
