# FCM-003 Evidence Index

Status: in-progress.

## Trigger

- FPG-002 PR #1980.
- CI run `32556780549`: `.agent/skills/**` entered unknown non-document fallback and selected unrelated product suites.

## Implementation

- Branch: `project/fcm-003-agent-skill-ci-classification`.
- `.github/workflows/ci.yml`: exact `.agent/skills/**` governance-safe classifier addition.
- `.agents/plugins/**` remains MCP runtime input.
- `.github/workflows/**` remains workflow guardrail input.
- Unknown non-document paths retain force-all fallback.

## Pending gates

- commit SHA
- PR number
- required PR CI / `CI result`
- merge-group CI
- merge commit
- canonical `main` verification
