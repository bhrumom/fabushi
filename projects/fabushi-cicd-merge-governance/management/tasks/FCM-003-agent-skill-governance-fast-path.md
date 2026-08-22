# FCM-003 — Agent/Skill Governance CI Classification

- **Task ID:** FCM-003
- **Status:** in-progress
- **Started:** 2026-08-22T14:24:00+08:00
- **Updated:** 2026-08-22T14:50:00+08:00
- **Completed:** pending

## Objective

Prevent repository-governance-only changes under `.agent/skills/**`, root Markdown governance files, `projects/**`, and `docs/**` from triggering the unknown-path fail-safe and unrelated Frontend/Worker/MCP/Electron suites, without weakening safety for runtime paths.

## Source / trigger

- FPG-002 PR #1980 / CI run `32556780549` proved `.agent/skills/**` was treated as an unknown non-document path.
- User requested cleanup and completion of the unfinished FCM-003 branch on 2026-08-22.

## In scope

- add `.agent/skills/**` to governance/docs-safe classification;
- preserve `.agents/plugins/**` in MCP runtime classification;
- preserve `.github/workflows/**` in workflow guardrails;
- preserve unknown non-document force-all behavior;
- validate through required PR CI and merge queue.

## Out of scope

- changing product test semantics;
- weakening the required aggregate `CI result`;
- bypassing protected `main` / merge queue;
- treating arbitrary `.agent/**` or unknown runtime paths as docs-safe.

## Acceptance criteria

1. `.agent/skills/**`, root Markdown, `projects/**`, and `docs/**` do not force all product domains when no runtime files changed.
2. `.agents/plugins/**` still selects MCP contracts.
3. `.github/workflows/**` still selects workflow guardrails.
4. Unknown non-document paths still fail safe to all canonical product domains.
5. Required `CI result` succeeds.
6. The change merges through protected `main` / merge queue.
7. Canonical `main` is re-read after merge and project records are closed with objective evidence.

## Implementation

- `.github/workflows/ci.yml`: add the exact matcher `^\.agent\/skills\/` to `isDocsSafe()`.
- No change to domain matchers or force-all logic.

## Verification

- Lightweight static classifier assertions before push.
- PR-head GitHub Actions selection.
- Merge-group required CI.
- Post-merge read from `main`.

## Branch / PR

- Branch: `project/fcm-003-agent-skill-ci-classification`
- PR: pending

## Evidence

- Trigger: PR #1980 / CI run `32556780549`.
- Implementation/CI/merge evidence: pending.

## Blockers / risks

- No implementation blocker.
- Local repository disk is nearly full; repository policy forbids local builds/tests, so verification is delegated to GitHub Actions.

## Next action

Commit and push the classifier + project records, open PR, verify required CI and merge queue, then close FCM-003 on canonical `main`.
