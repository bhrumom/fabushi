# FCM-010.11 canonical evidence — 2026-09-12

Project: `FAB-P0003 / FCM`
Task: `FCM-010.11`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Accepted implementation

- PR: `#2524` — `[automerge-force] ci: measure real validation-surface latency`
- PR head: `34ad4402b931ab38d766a898a7e93d44079aebfb`
- Protected merge: `2026-09-11T16:53:58Z`
- Canonical accepted SHA: `9cf785a3ef6ec819328e946a73c1d23aeb77039b`

## Live observer evidence

`CI latency observability` run `34624456844` completed successfully and uploaded:

- artifact: `fcm-ci-latency-34624456844`
- artifact id: `10274480654`
- digest: `sha256:ec1f3aa885d6ed6e8a42bb43646dc69fc3ac61467c0b93a964dff66bea758d3e`
- schema version: `2`
- observed workflow samples: `210`
- lookback: `14 days`

The generated report measured the real validation surfaces rather than stale historical job names:

| Surface | N | P50 | P95 | Budget | State |
|---|---:|---:|---:|---:|---|
| required-pr-ci | 30 | 17s | 22s | 180s | within-budget |
| required-merge-queue | 13 | 17s | 25s | 180s | within-budget |
| mahayana-pr-fast | 30 | 223s | 443s | 600s | within-budget |
| electron-pr-fast | 30 | 187s | 420s | 600s | within-budget |
| native-pr-fast | 30 | 51s | 1350s | 600s | over-budget |
| canonical-desktop | 25 | 747s | 1206s | 1800s | within-budget |
| canonical-mobile | 30 | 582s | 1152s | 1800s | within-budget |
| macos-packaged-interactive | 22 | 1658s | 3106s | 1800s | over-budget |

## Follow-up root-cause readback

Inspection of slow native PR runs showed the P95 outliers were dominated by GitHub-hosted runner allocation rather than test execution:

- run `34085360999`: direct Native Android job executed about 27 seconds after roughly 17 minutes of runner queue; aggregation-only `Native mobile result` then queued roughly another 7 minutes.
- run `34085360708`: direct Native Android job executed about 23 seconds after roughly 3 minutes of queue; aggregation-only `Native mobile result` then queued roughly another 19 minutes.

That evidence directly created FCM-010.12 to remove the aggregation-only runner and make release gates consume direct Android/iOS checks.

## Result

FCM-010.11 is accepted as **passed**. The observer is merged, live, schema-v2 evidence is retained, and its output has already identified the next concrete optimization targets rather than merely reporting a green telemetry workflow.
