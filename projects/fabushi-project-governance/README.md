# Fabushi Project Governance

## Objective

Make `projects/` the mandatory durable execution context for every task in `bhrumom/fabushi`, enforce an enterprise-standard project-folder model, and make root `AGENTS.md`, repository Skills, and Task Orchestration follow the same project-first lifecycle.

## Current verified status

`active` — FPG-001 established the repository-wide project gate. FPG-002 is upgrading the folder standard from a minimal scaffold to an enterprise project package and aligning Task Orchestration, root `AGENTS.md`, and the governance Skill.

## Current stage / next gate

Stage: `enterprise-standardization`.

Next gate: FPG-002 must pass Skill validation, GitHub `CI result`, protected merge/merge-queue policy, and canonical `main` verification before being marked complete.

## Scope summary

- mandatory project routing for every Fabushi task;
- enterprise project folder/file standard;
- project lifecycle and completion gates;
- stable task/requirement/evidence IDs;
- root `AGENTS.md` enforcement;
- `.agent/skills/fabushi-project-governance` enforcement;
- Task Orchestration alignment;
- project-folder governance for AGENTS/Skill/CI/CD/governance work itself.

## Major non-goals

- replacing GitHub code/CI/release evidence with project-document claims;
- storing credentials or private data in project records;
- creating a new project for every chat, branch, or PR;
- requiring empty documentation ceremony without an explicit N/A rationale.

## Canonical source

- Repository: `bhrumom/fabushi`
- Authoritative branch after merge: `main`
- Path: `projects/fabushi-project-governance/`
- Source intake: `source/`
- Governance skill: `.agent/skills/fabushi-project-governance/SKILL.md`
- Root enforcement: `AGENTS.md`

## Ownership

See `OWNERS.md`.

## Primary acceptance definition

Every repository task must first resolve a project under `projects/`; if none matches, it must create the enterprise-standard project folder and files before substantial work. AGENTS.md, Skill, CI/CD, documentation-governance, architecture-policy, and other meta work have no exemption. A task cannot be called complete until implementation, protected GitHub state, objective acceptance evidence, and project records agree.

## Navigation

- `SOURCE_OF_TRUTH.md` — precedence and authority
- `OWNERS.md` — accountability/review/escalation
- `source/` — original requirements and dated changes
- `docs/` — charter, scope, requirements, architecture, quality, release, SLO, security, DoD
- `management/` — roadmap, WBS, milestones, acceptance, RAID/risk, status, dependencies, changelog, issues/actions, task records
- `decisions/` — long-lived governance ADRs
- `evidence/` — GitHub/Skill validation evidence indexes
- `runbooks/` — repeatable governance operations when needed
