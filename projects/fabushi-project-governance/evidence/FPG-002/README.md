# FPG-002 Evidence Index

Status: in-progress pending CI/protected merge/canonical main verification.

## Source / requirements

- `source/2026-08-22-FPG-002-enterprise-project-standard.md`
- `docs/02-需求与成功指标.md`
- `management/tasks/FPG-002-enterprise-project-standard.md`

## Task Orchestration Skill evidence

- Complete updated Skill bundle generated: `skill.zip`
- Size: `16128 bytes`
- SHA-256: `95385f836c2c10eaf6e5ae0e22a4b04a91b4924cfdc215e021e199b0154efd61`
- Skill Creator `quick_validate.py /mnt/data/task-orchestration`: `Skill is valid!`
- Skill Creator `package_skill.py /mnt/data/task-orchestration /mnt/data/task-orchestration-dist`: validation and packaging succeeded.
- Bundle contains `task-orchestration/SKILL.md`, existing agents/assets/references, plus new `references/project-folder-standard.md`.
- Installation/activation in the user's current ChatGPT Skill library is **not** asserted by this evidence; delivery/install remains an external action.

## GitHub implementation evidence

- Branch: `project/fpg-002-enterprise-project-standard`
- Implementation PR: #1980
- PR URL: `https://github.com/bhrumom/fabushi/pull/1980`
- Initial PR head at creation: `79d80ba3aab78fbdefd613802f194c5064473122`
- Project-record update commit after PR creation: `8822003d4d84d18abaa66e17774e41ded202ba8a`

Implemented on branch:

- root `AGENTS.md` enterprise project-folder enforcement;
- `.agent/skills/fabushi-project-governance/SKILL.md`;
- governance `references/project-folder-standard.md`;
- governance `references/task-lifecycle.md`;
- `projects/fabushi-project-governance/` enterprise-standard self-migration;
- ADR-0002 enterprise project-folder standard;
- FPG-002 task, acceptance traceability, risk/dependency/action, runbook and project-folder audit records.

## Branch audit

- `evidence/FPG-002/project-folder-audit.md` confirms all mandatory enterprise scaffold files exist on the implementation branch.
- This proves branch structure only; canonical acceptance still requires protected merge and post-merge verification.

## Pending evidence

- final PR head SHA after record updates;
- required `CI result` run/job;
- merge queue/protected merge result;
- merge commit SHA;
- canonical `main` verification of root AGENTS, governance Skill/reference, and governance project standard files.
