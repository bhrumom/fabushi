# MSR-107 — current Codex/Grok Build capability and license refresh

- Project ID: `FAB-P0005`
- Task ID: `MSR-107`
- Status: `NOT_STARTED`
- Owner: Execution project group
- Dependency: none
- Parallel: yes

## Goal

Refresh existing MSR-101/102 inventory against pinned current revisions without importing code by assumption.

## Fixed inputs

- Codex `8e85265c39176b6bd498242a33d7b0f9b4b98303`, Apache-2.0 root LICENSE.
- Grok Build `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`, Apache-2.0 root LICENSE.

## Steps

Inventory session lifecycle, workflow/subagent, MCP/plugins/marketplace, policy/approval, network/process, worktree/checkpoint, model/config and observability capabilities. For each: current Mahayana equivalent, gap, adapt/reuse/reject, exact upstream file/revision/license, NOTICE/provenance obligation. Do not modify runtime implementation in this task.

## Acceptance

Source-backed matrix has no unclassified P0 capability; provenance ledger updated; reviewers can trace every reuse decision. Commit/PR project records only; no build/test claim.