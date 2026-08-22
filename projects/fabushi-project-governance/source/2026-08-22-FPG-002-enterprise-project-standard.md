# FPG-002 Source Requirement — Enterprise Project Folder Standard

Date: 2026-08-22

## User requirement

Standardize the project-folder structure created for Fabushi into Task Orchestration, using an enterprise/large-company project-document standard. The same project-folder requirement must apply to GitHub root `AGENTS.md` and repository Skills: AGENTS/Skill work must also be performed under a standard project folder rather than being treated as an exception.

## Normalized intent

1. Upgrade the Fabushi project-folder standard from a minimal scaffold to an enterprise project package.
2. Align root `AGENTS.md` with the same standard.
3. Align `.agent/skills/fabushi-project-governance` with the same standard.
4. Update Task Orchestration so repository engineering work locates/reuses or creates the standard project folder before substantial work.
5. Explicitly state that AGENTS.md, Skill, CI/CD, documentation governance, architecture-policy, release-tooling, and similar meta work has no exemption.
6. Upgrade `projects/fabushi-project-governance/` itself to the new standard as proof the governance task follows its own rule.
7. Preserve live GitHub/CI/release evidence as authoritative for engineering facts; external Sheets/Drive views may be management/control/mirror systems but must not silently override repository state.

## Acceptance intent

The task is complete only when:

- the Task Orchestration Skill package validates with the new project-folder reference and repository/meta-work rules;
- root `AGENTS.md` contains the enterprise scaffold and no-meta-exemption rule;
- the Fabushi governance Skill and lifecycle references contain the same model;
- the governance project itself contains all mandatory standard files (or explicit N/A with reason);
- FPG-002 task/WBS/acceptance/status/changelog/evidence records are updated;
- GitHub required CI/merge policy succeeds and canonical `main` is verified.
