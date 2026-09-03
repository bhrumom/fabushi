# FPG-002 Evidence Index

Status: passed after protected merge and canonical `main` verification.

## Source / requirements

- `source/2026-08-22-FPG-002-enterprise-project-standard.md`
- `docs/02-需求与成功指标.md`
- `management/tasks/FPG-002-enterprise-project-standard.md`

## Task Orchestration Skill evidence

- Updated complete Skill bundle: `skill.zip`
- Size: `16128 bytes`
- SHA-256: `95385f836c2c10eaf6e5ae0e22a4b04a91b4924cfdc215e021e199b0154efd61`
- Skill Creator `quick_validate.py`: `Skill is valid!`
- Skill Creator `package_skill.py`: succeeded.
- Bundle contains original agents/assets/references plus new repository enterprise project-folder standard.
- Installation/activation in the user's current ChatGPT Skill library is not asserted; that remains an external action.

## GitHub implementation evidence

- Branch: `project/fpg-002-enterprise-project-standard`
- PR: #1980
- Final PR head: `b6c15759f110228b982846baabdb48ef8f44ba68`
- Required CI: run `32556780549`, `CI result` success.
- Merge queue/protected merge: passed.
- Merge commit: `e77e11d4cb4e96e59ae35859cc159874bb93180d`.

## Canonical main verification

Verified after merge:

- root `AGENTS.md` includes enterprise scaffold and explicit no-meta-work exemptions;
- `.agent/skills/fabushi-project-governance/SKILL.md` includes the same enterprise/no-meta model;
- `projects/fabushi-project-governance/evidence/FPG-002/project-folder-audit.md` exists on main with all mandatory scaffold items checked.

## CI optimization observation

PR #1980 also proved `.agent/skills/**` currently enters the unknown-path fail-safe and selected unrelated product suites. This is intentionally tracked in the separate `projects/fabushi-cicd-merge-governance/` task FCM-003 so CI policy and governance policy remain separate concerns.
