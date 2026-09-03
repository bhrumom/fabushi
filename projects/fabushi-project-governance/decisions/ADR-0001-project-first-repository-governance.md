# ADR-0001 — Project-First Repository Governance

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

Long-running Fabushi work spans chats, agents, PRs, CI runs, and releases. Chat memory alone cannot provide durable scope, status, and acceptance evidence.

## Decision

Every task must begin by resolving a canonical `projects/<slug>/` folder on GitHub `main`. Existing objectives reuse their project folder; genuinely different objectives create the standard scaffold before substantial work. Completion requires project-record updates and GitHub evidence.

The root `AGENTS.md` is the repository-wide enforcement instruction; `.agent/skills/fabushi-project-governance/` contains detailed lifecycle rules.

## Consequences

- Agents must perform project intake before substantive work.
- New independent workstreams incur a small documentation bootstrap cost.
- Cross-session continuity and auditability improve.
- GitHub project records become authoritative over chat memory and external mirrors.
