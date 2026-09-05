# MSR-107 — Current upstream source/provenance capability audit

- Project: `FAB-P0005 / MSR`
- Task ID: `MSR-107`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `0`
- Risk: low; records/evidence only

## Single objective

Refresh the open-source-first matrix against exact current pins and inspect the source paths that materially affect Bot session, workflow/subagent, tool/policy, checkpoint/worktree and MCP/app-server design before any new MSR runtime implementation.

## Exact upstream pins for this architecture revision

- `xai-org/grok-build@72a61251fcffb464bcc687aeb5a998e5a98ec0c9` — Apache-2.0.
- `openai/codex@ddf04ad26789d040f9ef6a96736f76602e35a6cc` — Apache-2.0.
- `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` — behavior/protocol evidence only; provenance states no upstream source-code license is implied.

## Exact output allowlist

- `projects/mahayana-sovereign-runtime/docs/08-upstream-capability-matrix.md`
- `projects/mahayana-sovereign-runtime/evidence/MSR-107/README.md`
- `projects/mahayana-sovereign-runtime/evidence/MSR-107/upstream-lock.json`
- this task/status record only

Forbidden: all product/runtime/test/workflow/dependency/version code.

## Acceptance

For each candidate capability record exact upstream file/symbol, observed behavior, Fabushi current file/symbol, gap status (`native`, `partial`, `planned`, `reject`), adaptation decision, license/provenance and required tests. Explicitly audit: durable session/recovery; approvals/sandbox/tool bus; MCP/tool elicitation; provider/app-server; queue/workflow/subagent; checkpoints/worktrees; compaction/reinjection; liveness/circuit breaking; telemetry. Grok Bot reconstructed material may identify behavior to reproduce but may not contribute copied source.

If an upstream moves after this pin, record the new SHA separately; do not silently substitute it into this revision.

## Evidence

Source URLs/SHAs, license files, inspected path list and a machine-readable lock file. No implementation claim is allowed from this task.
