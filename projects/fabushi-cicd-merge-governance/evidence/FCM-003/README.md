# FCM-003 Evidence Index

Status: passed; implementation and post-fix governance smoke both passed protected PR + merge-group CI and merged to canonical `main`.

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

- Closure/smoke PR: #1985.
- Head commit: `c0b89c4c115d9065df57d7dd36d8510f05ce1182`.
- PR CI run: `32558243330` — success.
- Merge-group CI run: `32558267502` — success.
- Both runs executed only `Classify CI changes` + required `CI result`; Frontend, Worker, MCP, Electron, and Canonical architecture guardrails were skipped.
- Merge commit: `fc4e0521a0bac8729632432acb6149cad5ab403d`.
- Result: real `.agent/skills/**` + `projects/**` changes now use the intended governance fast path in both PR and merge-group contexts.
