# FPG-002 — Enterprise Project Folder Standard

- **Task ID:** FPG-002
- **Status:** passed
- **Started:** 2026-08-22T14:09:00+08:00
- **Updated:** 2026-08-22T14:26:24+08:00
- **Completed:** 2026-08-22T14:26:24+08:00

## Objective

Upgrade Fabushi project governance from the original minimal project scaffold to an enterprise-standard project folder and align Task Orchestration, root `AGENTS.md`, and `.agent/skills/fabushi-project-governance` with the same rules, including no exemptions for AGENTS/Skill/CI/governance work.

## Source requirement

- `../../source/2026-08-22-FPG-002-enterprise-project-standard.md`
- Requirements: FPG-R01 through FPG-R07 in `../../docs/02-需求与成功指标.md`

## Acceptance result

1. Task Orchestration contains enterprise repository project-folder rules and reusable `references/project-folder-standard.md`: passed.
2. Task Orchestration covers AGENTS.md, Skills, CI/CD, architecture/documentation governance and other meta work: passed.
3. Task Orchestration validator and `skill.zip` package: passed.
4. Root `AGENTS.md` enterprise scaffold/no-meta-exemption on main: passed.
5. Governance Skill/reference/lifecycle alignment on main: passed.
6. Governance project mandatory standard files on main: passed.
7. ADR-0002 enterprise project-folder standard: passed.
8. FPG-002 project records/evidence: passed with this closure.
9. GitHub required `CI result` + protected merge queue: passed.
10. Canonical `main` verification: passed.

## GitHub evidence

- Implementation branch: `project/fpg-002-enterprise-project-standard`
- Implementation PR: #1980
- Final PR head: `b6c15759f110228b982846baabdb48ef8f44ba68`
- Required CI run: `32556780549`; `CI result` success.
- Protected merge/merge queue: passed.
- Merge commit: `e77e11d4cb4e96e59ae35859cc159874bb93180d`.
- Post-merge main verification: root `AGENTS.md`, governance Skill and FPG-002 project-folder audit fetched successfully from `main`.

## Skill package evidence

- Bundle: `skill.zip`
- SHA-256: `95385f836c2c10eaf6e5ae0e22a4b04a91b4924cfdc215e021e199b0154efd61`
- Size: `16128 bytes`
- `quick_validate.py`: passed.
- `package_skill.py`: passed.
- Installation state: not claimed; package delivery/installation is a separate external action.

## Implementation summary

Root `AGENTS.md`, Fabushi governance Skill/reference/lifecycle and the governance project itself now implement one enterprise project standard: ownership, stable requirements/IDs, architecture/quality/release/SLO/security docs, roadmap/WBS/milestones/acceptance/risk/dependencies/status/changelog/issues, ADRs, evidence, runbooks, explicit N/A rules and no meta-work exemption.

## Remaining work

- FPG-I05: user/product action to install/replace the packaged Task Orchestration Skill if desired.
- FPG-003: evaluate automated project-record guardrails after adoption evidence.
- Separate CI/CD project FCM-003 tracks the discovered `.agent/skills/**` path-classification inefficiency; it does not change FPG-002 acceptance.
