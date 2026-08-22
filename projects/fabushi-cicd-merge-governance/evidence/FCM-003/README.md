# FCM-003 Evidence Index

Status: passed after protected merge and canonical `main` verification; closure smoke pending merge.

## Trigger

- FPG-002 PR #1980.
- CI run `32556780549`: `.agent/skills/**` entered unknown non-document fallback and selected unrelated product suites.

## Implementation

- Branch: `project/fcm-003-agent-skill-ci-classification`.
- Commit: `9187fb6f8cfbca8e9ac1f25a61aa12bb6a4fa0a5`.
- PR: #1984.
- `.github/workflows/ci.yml`: exact `.agent/skills/**` governance-safe classifier addition.
- `.agents/plugins/**` remains MCP runtime input.
- `.github/workflows/**` remains workflow guardrail input.
- Unknown non-document paths retain force-all fallback.

## PR validation

- PR CI run: `32558117683` — success.
- `Classify CI changes` — success.
- `Canonical architecture guardrails` — success because this PR changed `ci.yml`.
- Frontend / Worker / MCP / Electron product suites — skipped.
- Required `CI result` — success.

## Merge queue validation

- Merge-group CI run: `32558147639` — success.
- Frontend / Worker / MCP / Electron product suites — skipped.
- Required `CI result` — success.
- Merge commit: `3a06560ce2b9d8d850f6f15e008ae9b0cf1f997b`.

## Canonical main verification

- Re-read `main:.github/workflows/ci.yml`; `isDocsSafe()` contains `^\.agent\/skills\/`.
- No domain matcher or unknown force-all behavior was removed.

## Closure smoke

This closure PR intentionally changes `.agent/skills/fabushi-project-governance/SKILL.md` plus `projects/**`. It must prove that governance-only Skill/project changes do not trigger Frontend, Worker, MCP, Electron, or workflow guardrail suites. Required aggregate `CI result` must still pass on both PR and merge-group events.
