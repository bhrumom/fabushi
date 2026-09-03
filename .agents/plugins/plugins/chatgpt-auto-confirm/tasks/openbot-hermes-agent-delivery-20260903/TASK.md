# TASK

1. Inventory existing Mahayana run/event/artifact/delivery and desktop/Web projections; map upstream ideas to existing boundaries.
2. Extend canonical Bot run/delivery contracts only where gaps exist; persist and stream lifecycle/tool/approval/error/delegation/artifact/delivery/control events.
3. Wire desktop and Web to the same state for live progress and controls; preserve historical recovery.
4. Implement delivery cards and retry/open/download actions over canonical artifact/delivery records.
5. Extend chatgpt-auto-confirm durable queue state with per-turn wall timestamps, monotonic durations, conversation ID, same-chat follow-up count and new-chat continuation count.
6. Implement/test continuation policy: <1200 seconds + follow-ups <2 => same Chat; otherwise fresh Chat; abnormal renderer recovery remains idempotent and auditable.
7. Add CI regression coverage and task-specific E2E evidence.
8. Merge through main, run exact-main packaged/E2E gates, bump version/changelog as required and publish a GitHub Release traceable to the accepted main SHA.

No item is complete without objective GitHub evidence.