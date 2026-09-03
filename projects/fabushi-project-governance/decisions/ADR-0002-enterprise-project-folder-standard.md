# ADR-0002 — Enterprise Project Folder Standard

- **Status:** Accepted for FPG-002 implementation; canonical after protected merge
- **Date:** 2026-08-22
- **Decision owners:** repository governance / maintainers

## Context

FPG-001 established a minimal `projects/<slug>/` scaffold and root Project-First gate. Real usage showed that the minimum scaffold did not explicitly cover ownership, stable requirements/success metrics, milestones, dependencies/blockers, issues/actions, quality strategy, release/rollback, observability/SLO, security/privacy/compliance, or runbooks. Task Orchestration also lacked a repository project-folder contract, and meta work such as AGENTS/Skill changes needed an explicit no-exemption rule.

## Decision

Adopt the enterprise project-folder standard defined in `.agent/skills/fabushi-project-governance/references/project-folder-standard.md`.

Mandatory project areas are:

- project identity/ownership/source-of-truth;
- source intake;
- charter, scope, requirements/success metrics, architecture, quality, release/rollback, SLO/operations, security/privacy/compliance, DoD;
- roadmap, WBS, milestones, acceptance traceability, risks, dependencies/blockers, append-only status/changelog, issues/actions, task records;
- ADRs, evidence indexes, runbooks.

Mandatory files that do not apply must contain an explicit N/A with reason, owner, and revisit trigger rather than being omitted or left empty.

AGENTS.md, Skills, CI/CD, merge/release policy, architecture standards, documentation governance, build/release tooling, and security/governance automation have no exemption from project routing.

Task Orchestration should use the same repository project model for engineering work while keeping Google Sheets as portfolio/control-plane view rather than replacing repository specifications or live GitHub evidence.

## Alternatives considered

1. Keep the minimal scaffold only — rejected because important enterprise execution/operations fields remain implicit and drift between projects.
2. Require every possible specialist document with no N/A mechanism — rejected as excessive ceremony for small/non-runtime projects.
3. Put all project state only in Google Sheets/Drive — rejected for Fabushi engineering work because repository specs, code, PR, CI, release, and evidence need durable co-location and protected version history.

## Consequences

Positive:

- new agents/engineers can reconstruct projects without chat history;
- stronger requirement-to-evidence traceability;
- meta/governance work follows its own policy;
- shared stable IDs across Task Orchestration and GitHub;
- operational/security/release concerns become explicit when relevant.

Costs:

- more standard files per project;
- existing projects need incremental migration when touched;
- maintainers must prevent low-value boilerplate by using meaningful N/A rationale.

## Migration

Do not mass-rewrite every historical project immediately. Audit and migrate an existing project when it receives substantive work or an explicit governance migration task. `projects/fabushi-project-governance/` is migrated during FPG-002 as the reference implementation.

## Supersedes / superseded by

Extends ADR-0001 project-first repository governance. Does not supersede the Project-First principle.
