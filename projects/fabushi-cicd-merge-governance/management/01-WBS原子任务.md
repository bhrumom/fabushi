# WBS 原子任务

| Task ID | Atomic task | Required | Acceptance | Status |
|---|---|---:|---|---|
| FCM-001.1 | Fix merge-group impact classification | yes | merge-group diff no longer force-all; correct base/head | in-progress |
| FCM-001.2 | Add docs fast path + unknown fail-safe | yes | docs selects no product jobs; unknown code selects all | in-progress |
| FCM-001.3 | Make automerge merge-queue-aware | yes | no direct protected-branch REST merge | in-progress |
| FCM-001.4 | Gate Worker CD by changed inputs | yes | docs-only main push skips deploy | in-progress |
| FCM-001.5 | Gate Fabushi Pay CD by changed inputs | yes | docs-only main push skips deploy | in-progress |
| FCM-001.6 | Update enterprise branch/merge policy | yes | policy matches implementation | in-progress |
| FCM-001.7 | Validate PR + merge queue + record timing | yes | CI success and merge through queue | not-started |
