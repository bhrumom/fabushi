# FPG-002 — Enterprise Project Folder Standard

- **Task ID:** FPG-002
- **Status:** in-progress
- **Started:** 2026-08-22T14:09:00+08:00
- **Updated:** 2026-08-22T14:22:00+08:00
- **Completed:** pending

## Objective

Upgrade Fabushi project governance from the original minimal project scaffold to an enterprise-standard project folder and align Task Orchestration, root `AGENTS.md`, and `.agent/skills/fabushi-project-governance` with the same rules, including no exemptions for AGENTS/Skill/CI/governance work.

## Source requirement

- `../../source/2026-08-22-FPG-002-enterprise-project-standard.md`
- Requirements: FPG-R01 through FPG-R07 in `../../docs/02-需求与成功指标.md`

## In scope

- enterprise project-folder standard;
- root `AGENTS.md` project scaffold and no-meta-exemption rule;
- governance Skill and lifecycle references;
- Task Orchestration Skill bundle update;
- migrate `projects/fabushi-project-governance/` itself to the new standard;
- FPG-002 WBS/acceptance/status/change/evidence closure;
- protected GitHub PR/CI/merge verification.

## Out of scope

- automatically installing the packaged Task Orchestration Skill into every ChatGPT product/runtime;
- mass-migrating every historical Fabushi project in the same PR;
- adding CI enforcement for project-folder mandatory files (candidate FPG-003);
- product runtime code changes.

## Dependencies

See `../06-依赖与阻塞.md`.

## Acceptance criteria

1. Task Orchestration includes enterprise repository project-folder rules and a reusable `references/project-folder-standard.md`.
2. Task Orchestration explicitly covers AGENTS.md, Skills, CI/CD, architecture/documentation governance, and other meta work.
3. Task Orchestration validator passes and `skill.zip` packages successfully.
4. Root `AGENTS.md` contains the enterprise scaffold and no-meta-exemption rule.
5. Governance Skill/reference/lifecycle align with the same standard.
6. `projects/fabushi-project-governance/` contains all mandatory standard files or explicit N/A rationale.
7. An ADR records adoption of the enterprise standard.
8. FPG-002 project records/evidence are complete.
9. GitHub required `CI result` passes and changes merge through protected main/merge queue.
10. Canonical `main` is verified after merge.

## Verification

- Skill Creator `quick_validate.py` on Task Orchestration bundle.
- Skill Creator `package_skill.py` and SHA-256 evidence.
- Inspect root `AGENTS.md`, governance Skill and standard/lifecycle references.
- Project-folder audit against the mandatory scaffold.
- GitHub PR/CI/merge queue evidence.
- Post-merge fetch from `main`.

## Branch / PR

- Branch: `project/fpg-002-enterprise-project-standard`
- Implementation PR: #1980
- Initial PR head before this evidence update: `79d80ba3aab78fbdefd613802f194c5064473122`
- Current branch head: this task-record update and subsequent project-record commits; final PR head will be read from GitHub before CI/merge evidence is closed.

## Implementation summary

In progress. The branch contains enterprise standard changes to root `AGENTS.md`, governance Skill/reference/lifecycle, expanded project metadata/source/ownership, new governance engineering documents, milestones/dependencies/issues, ADR-0002, runbook index, FPG-002 task/evidence, and a branch project-folder audit.

The Task Orchestration Skill has been rebuilt as a complete bundle with the new standard and validated with Skill Creator tooling.

## Skill package evidence

- Bundle: `skill.zip`
- SHA-256: `95385f836c2c10eaf6e5ae0e22a4b04a91b4924cfdc215e021e199b0154efd61`
- Size: `16128 bytes`
- `quick_validate.py`: passed
- `package_skill.py`: passed
- Installation state: not claimed; package delivery/installation is a separate external action.

## Evidence

See `../../evidence/FPG-002/README.md`.

## Blockers / risks

No implementation blocker. Canonical completion remains blocked on GitHub PR #1980 required checks, protected merge, post-merge verification, and project-record closure.

## Next action

Run PR #1980 required CI, inspect selected/skipped jobs, merge through repository policy, verify `main`, then close FPG-002 in a final records-only change if required.
