# FPG-004 — Global Project Identifiers

- Portfolio Project ID: `FAB-P0002`
- Project Key: `FPG`
- Task ID: `FPG-004`
- Project: Fabushi Project Governance
- Status: `passed`
- Started: 2026-08-22T16:06:00+08:00
- Updated: 2026-08-22T16:22:30+08:00
- Completed: 2026-08-22T16:22:30+08:00
- Implementation branch: `governance/global-project-identifiers`
- Closure branch: `docs/fpg-004-project-id-closure`
- Implementation PR: `#1996`
- Implementation merge commit: `87462b14017b08f0f4dcd6f97fbea67b5c12d791`

## Objective

Introduce a portfolio-wide immutable Project ID system for all Fabushi repository projects, backfill current canonical projects, and enforce future allocation through repository governance and CI.

## Source requirements

- `source/2026-08-22-FPG-004-global-project-identifiers.md`
- User requirement: implement numbering **between projects** using enterprise/large-company governance practices.

## Scope delivered

- Defined canonical Project ID format and lifecycle.
- Created authoritative machine-readable portfolio registry and human index/policy.
- Backfilled every canonical `projects/*/PROJECT.yaml` with a global Project ID and stable Project Key/legacy aliases.
- Preserved existing task namespaces and historical identifiers.
- Updated repository project standard, governance Skill/lifecycle, and root Agent instructions.
- Added CI validation for format, uniqueness, registry parity, monotonic allocation, and immutability.
- Recorded ADR, WBS, acceptance, status, changelog, and evidence.

## Deterministic migration ordering and final allocation

Existing projects were ordered by the first formal project-folder commit merged to canonical `main`:

| Portfolio Project ID | Project Key | Slug | First formal main commit |
|---|---|---|---|
| `FAB-P0001` | `TFI` | `telegram-fabushi-integration` | `99cd4b227a34b49fc04c3265c1dfdee585344160` |
| `FAB-P0002` | `FPG` | `fabushi-project-governance` | `eaf273dafc140619b06b46a4d7d234997acde05d` |
| `FAB-P0003` | `FCM` | `fabushi-cicd-merge-governance` | `ac94b40d4a05a0211146c2bb5904aa936a7bc928` |
| `FAB-P0004` | `GBF` | `grok-bot-fabushi-integration` | `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c` |
| `FAB-P0005` | `MSR` | `mahayana-sovereign-runtime` | `88db63c328c3cba39971f3942509cb0b582502bc` |

Canonical `main` registry high-water mark after migration: `next_sequence=6`, so the next *candidate* allocation is `FAB-P0006`. It is not reserved; future creation must re-read live `main` before allocation.

## Implementation result

- `projects/PORTFOLIO.json` is the authoritative allocation registry.
- `projects/PROJECT_ID_POLICY.md` defines immutable, monotonic, no-reuse lifecycle semantics.
- `projects/README.md` provides the human portfolio index.
- All five canonical project folders mirror their registered `project_id`, `project_key`, slug, and path.
- Historical identifiers remain under `legacy_project_ids` and are not reassigned.
- `scripts/check-project-portfolio.py` validates schema, format, uniqueness, contiguous allocation, `next_sequence=max+1`, folder parity, metadata parity, baseline immutability, and new-allocation sequencing.
- `.github/workflows/project-portfolio-governance.yml` runs the validator on relevant PR/push changes.
- Root `AGENTS.md`, governance Skill, project-folder standard, and task lifecycle require new independent projects to allocate the current registry `next_sequence` atomically in the same PR as project creation.

## Acceptance results

1. **PASS** — all current canonical project folders have unique `FAB-P0001`–`FAB-P0005` Project IDs.
2. **PASS** — mnemonic namespaces remain as Project Keys and historical identifiers remain as aliases.
3. **PASS** — canonical `projects/PORTFOLIO.json` exists with `next_sequence=6=max(sequence)+1`.
4. **PASS** — registry/project-folder parity passed the automated validator and was re-read from `main`.
5. **PASS** — baseline-aware CI validator passed on PR #1996 and enforces malformed/duplicate/gap/reuse/mutation/removal failures.
6. **PASS** — root Agent and governance Skill/reference/lifecycle all contain the same allocation contract.
7. **PASS** — required CI passed, PR entered merge queue, merged, and canonical `main` was re-verified.

## Verification evidence

- Implementation PR: #1996, merged 2026-08-22T08:21:57Z.
- PR head used for final PR checks: `a50dd46b2bedf152356c14ac195021ffc9443013`.
- Project portfolio governance run: `32561929188` — `Validate immutable Project IDs` = success.
- Repository CI run: `32561929208` — selected jobs and final `CI result` = success.
- Explicit automerge run: `32561929220` = success.
- Merge queue: GitHub rejected an immediate merge attempt with `Pull Request is in the merge queue`, confirming protected queue routing.
- Merge commit on canonical main: `87462b14017b08f0f4dcd6f97fbea67b5c12d791`.
- Post-merge main reads verified:
  - `projects/PORTFOLIO.json` with five entries and `next_sequence=6`;
  - Telegram `PROJECT.yaml` = `FAB-P0001 / TFI`;
  - Project Governance `PROJECT.yaml` = `FAB-P0002 / FPG`;
  - CI/CD Governance `PROJECT.yaml` = `FAB-P0003 / FCM`;
  - Grok Bot `PROJECT.yaml` = `FAB-P0004 / GBF`;
  - Mahayana `PROJECT.yaml` = `FAB-P0005 / MSR`;
  - root `AGENTS.md` global Project ID allocation gate;
  - `.github/workflows/project-portfolio-governance.yml` validator workflow.

## Evidence index

- `projects/fabushi-project-governance/evidence/FPG-004/README.md`

## Risks / residual notes

- Historical documents may still use old values under the label `project_id`; the migration deliberately preserves those values as aliases instead of rewriting history.
- Concurrent project creation remains intentionally serialized through `projects/PORTFOLIO.json` merge conflicts.
- `FAB-P0006` is only the current next value, not a reservation. A future project must allocate whatever live canonical `main` says at creation time.

## Blockers

None.

## Next action

No further FPG-004 implementation is required. Future independent Fabushi projects must follow the canonical registry allocation gate; continuations must reuse their existing Project ID.