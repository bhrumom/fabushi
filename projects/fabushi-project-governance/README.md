# Fabushi Project Governance

## Objective

Make `projects/` the mandatory durable execution context for every task in `bhrumom/fabushi`, and make the root `AGENTS.md` enforce project-first intake, execution, verification, and closure.

## Status

`active`

## Current stage

Repository-wide bootstrap: establish the root `AGENTS.md` project gate and canonical governance project folder.

## Canonical source

- Repository: `bhrumom/fabushi`
- Branch after merge: `main`
- Path: `projects/fabushi-project-governance/`
- Original requirement: `source/README.md`
- Governance skill: `.agent/skills/fabushi-project-governance/SKILL.md`

## Primary acceptance definition

Every repository agent task must first resolve a project under `projects/`; if none matches, it must create the standardized project folder and files before substantial work. A task cannot be called complete until its project record is updated with status, acceptance, and evidence.

## Navigation

- `SOURCE_OF_TRUTH.md` — precedence and authority
- `docs/` — scope and acceptance definition
- `management/` — roadmap, WBS, acceptance, risk, status, changelog, task records
- `decisions/` — long-lived governance decisions
- `evidence/` — GitHub evidence indexes
