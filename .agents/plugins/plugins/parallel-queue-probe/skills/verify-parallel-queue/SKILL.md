---
name: verify-parallel-queue
description: Verify GitHub Actions evidence for Mahayana dynamic task-queue concurrency. Use when a user asks whether the miniapp really ran multiple tasks in parallel or whether the parallel queue smoke test passed.
---

# Verify Parallel Queue

Use `verify_parallel_queue` with the `parallel-queue-evidence.json` artifact from
the ChatGPT auto-confirm runner.

Pass only when all checks are true:

- task B was added after task A had already entered `running`;
- one queue-status observation contains both tasks in `running`;
- `requestedMaxConcurrent` and `effectiveMaxConcurrent` are at least 2;
- the two tasks have different non-empty hidden target ids;
- both active workers report `visibilityVerified: true`;
- the execution mode is
  `single-authenticated-process-multi-hidden-window-parallel`.

Do not accept a configured `maxConcurrent` value alone as proof of parallel
execution. Return every failed criterion and keep the Action failed until all
criteria pass.
