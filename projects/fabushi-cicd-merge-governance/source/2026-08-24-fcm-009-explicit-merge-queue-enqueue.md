# 2026-08-24 — FCM-009 deterministic protected merge-queue enqueue

## Trigger

After all PR product gates were green, the `Explicit automerge` workflow repeatedly reported that native auto-merge was armed, but PR #2083 still had no `mergeQueueEntry` and no new merge-group validation branch. This left a green PR waiting indefinitely and blocked the exact-main E2E → Release loop.

## GitHub contract review

GitHub's GraphQL API exposes `enqueuePullRequest`, whose contract is explicitly “Add a pull request to the merge queue.” GitHub's merge-queue documentation likewise distinguishes adding a PR to the queue from ordinary auto-merge: once required checks pass, the PR must be added to the queue, after which GitHub creates a temporary merge group and reruns required checks against the latest base.

## Decision

The repository `automerge` label is an authorization signal, not permission to bypass protected main. After the required workflow checks are green, the automation now invokes `enqueuePullRequest` directly. The queue's configured merge method (SQUASH), ALLGREEN grouping strategy, minimum wait, and merge-group `CI result` remain authoritative.

The workflow no longer treats `autoMergeRequest` as success, because an armed auto-merge request is not proof that a merge-queue entry exists. It records success only after the GraphQL enqueue mutation returns a `mergeQueueEntry`.
