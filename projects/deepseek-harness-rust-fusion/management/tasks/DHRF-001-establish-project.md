# DHRF-001 — Establish governed project

- Status: `in-progress`
- Started: 2026-08-22
- Updated: 2026-08-22
- Completed: -

## Objective
Create the enterprise-standard GitHub project folder that will govern Rust-native DeepSeek Harness convergence into Fabushi.

## Source requirements
- `source/user-requirement-2026-08-22.md`
- `source/upstream-baseline.md`
- Repository `AGENTS.md` and Fabushi project-governance skill.

## In scope
Project identity/ownership; source pin; scope/requirements/architecture/quality/release/SLO/security/DoD; roadmap/WBS/milestones/acceptance/risks/dependencies/status/changelog/actions; ADR; evidence/runbook indexes.

## Out of scope
Runtime feature implementation. That begins with DHRF-101 source inventory and subsequent WBS tasks.

## Dependencies
None beyond GitHub repository access and current `main` governance rules.

## Acceptance criteria
1. Full mandatory project scaffold exists and is non-empty.
2. Original requirement and pinned upstream baseline are durable.
3. Stable Project/Requirement/Task/Milestone IDs exist.
4. Existing Mahayana Harness code is acknowledged as the convergence baseline.
5. Architecture boundary and non-goals are explicit.
6. Project change is merged through GitHub and verified on canonical `main`.

## Verification
Repository tree inspection and post-merge file fetch from `main`.

## Branch / commit / PR
To be recorded after GitHub write/PR creation.

## Implementation summary
Prepared project documentation only; no runtime code changed.

## Evidence
See `evidence/DHRF-001/README.md`.

## Blockers / risks
Protected-main merge and canonical verification pending.

## Next action
Open/merge project documentation PR, verify `main`, then close DHRF-001 and start DHRF-101.
