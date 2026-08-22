# FPG-004 — Global Project Identifiers

- Task ID: `FPG-004`
- Project: Fabushi Project Governance
- Status: `in-progress`
- Started: 2026-08-22T16:06:00+08:00
- Updated: 2026-08-22T16:06:00+08:00
- Completed: pending
- Branch: `governance/global-project-identifiers`
- Commit: pending
- PR: pending

## Objective

Introduce a portfolio-wide immutable Project ID system for all Fabushi repository projects, backfill current canonical projects, and enforce future allocation through repository governance and CI.

## Source requirements

- `source/2026-08-22-FPG-004-global-project-identifiers.md`
- User requirement: implement numbering **between projects** using enterprise/large-company governance practices.

## In scope

- Define canonical Project ID format and lifecycle.
- Create authoritative machine-readable portfolio registry and human index/policy.
- Backfill every canonical `projects/*/PROJECT.yaml` on `main` with a global Project ID and stable project key/legacy aliases.
- Preserve existing task namespaces and historical identifiers.
- Update repository project standard, governance Skill/lifecycle, and root Agent instructions.
- Add CI validation for format, uniqueness, registry parity, monotonic allocation, and immutability.
- Record ADR, WBS, acceptance, status, changelog, and evidence.

## Out of scope

- Renaming project directories solely to match numeric IDs.
- Rewriting historical task IDs, PR numbers, commit messages, or document history.
- Creating a separate external portfolio database as the engineering source of truth.

## Deterministic migration ordering

Existing projects are ordered by the first formal project-folder commit merged to canonical `main`:

1. Telegram project — PR #1975 / commit `99cd4b227a34b49fc04c3265c1dfdee585344160`.
2. Project Governance — PR #1976 / commit `eaf273dafc140619b06b46a4d7d234997acde05d`.
3. CI/CD & Merge Governance — PR #1978 / commit `ac94b40d4a05a0211146c2bb5904aa936a7bc928`.
4. Grok Bot fusion — PR #1982 / commit `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c`.
5. Mahayana sovereign runtime — PR #1989 / commit `88db63c328c3cba39971f3942509cb0b582502bc`.

## Planned allocation

| Portfolio Project ID | Project Key | Slug |
|---|---|---|
| FAB-P0001 | TFI | telegram-fabushi-integration |
| FAB-P0002 | FPG | fabushi-project-governance |
| FAB-P0003 | FCM | fabushi-cicd-merge-governance |
| FAB-P0004 | GBF | grok-bot-fabushi-integration |
| FAB-P0005 | MSR | mahayana-sovereign-runtime |

Next allocatable ID after migration: `FAB-P0006`.

## Acceptance criteria

1. All current canonical project folders have one unique `project_id` matching `^FAB-P[0-9]{4}$`.
2. Existing mnemonic IDs remain available as `project_key` and/or `legacy_project_ids`.
3. `projects/PORTFOLIO.json` is the authoritative allocation registry and its `next_sequence` equals max allocated sequence + 1.
4. Registry entries exactly match canonical project folders and each `PROJECT.yaml` identity/path.
5. CI rejects duplicate IDs/keys/slugs, malformed IDs, gaps/reuse, registry/folder divergence, and mutation/removal of already-registered IDs when compared with the target branch.
6. Root `AGENTS.md`, governance Skill, project-folder standard, and task lifecycle describe the same allocation process.
7. PR CI passes, protected merge completes, and canonical `main` is re-fetched before closure.

## Verification

- Static registry validator in GitHub Actions.
- Review all `PROJECT.yaml` files and registry entries.
- PR required checks / merge queue.
- Post-merge `main` verification.

## Evidence plan

- `projects/fabushi-project-governance/evidence/FPG-004/README.md`
- Branch commit SHAs.
- PR number and review/check evidence.
- Workflow run/job for portfolio validator.
- Post-merge main file reads.

## Risks

- Historical references may call old values “project_id”; mitigate by preserving aliases and documenting `project_key` versus canonical portfolio `project_id`.
- Concurrent new project creation can race for the same next sequence; registry merge conflicts are intentional serialization and must be resolved before merge.

## Next action

Implement registry/policy, backfill all canonical project metadata, add validator + CI, align repository governance instructions, then run GitHub Actions and close only after protected merge/main verification.
