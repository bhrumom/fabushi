# FCM-002 — CI latency observability and SLO

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-002
- **Status:** in-progress
- **Started:** 2026-08-22
- **Updated:** 2026-08-22

## Objective

Turn the fast-path improvements already landed by FCM-001/FCM-003 into a continuously measurable CI latency service level objective. Track recent `CI` workflow wall-clock latency by actual selected job surface, publish P50/P95 and queue delay, preserve machine-readable evidence, and keep the observer itself lightweight.

## Source requirements

- `source/README.md`: make documentation/governance changes fast without weakening required checks or merge queue safety.
- `management/00-路线图.md`: G1 — measure P50/P95 by change tier and establish latency SLOs.
- `management/01-WBS原子任务.md`: FCM-002.

## In scope

- Scheduled/manual CI latency measurement using GitHub Actions APIs without repository checkout.
- Change-surface buckets derived from actual non-skipped canonical CI jobs.
- P50/P95 wall time and runner queue delay.
- GitHub Actions job-summary dashboard plus JSON/CSV artifact evidence.
- Soft SLO evaluation that reports breaches without making historical measurement itself a merge blocker.

## Out of scope

- Replacing GitHub-hosted runners.
- Hiding or bypassing slow required checks.
- Treating network/runner queue variance as a product test failure.

## Dependencies

- Existing canonical `.github/workflows/ci.yml` job names and aggregate `CI result`.
- GitHub Actions `actions: read` permission.

## Acceptance criteria

1. A dedicated workflow can query recent completed `CI` runs and their jobs without checkout.
2. It groups runs by observed validation surface (`fast-path`, `workflow-governance`, `single-domain`, `multi-domain`, `full-canonical`).
3. It reports sample count, P50, P95, queue-delay P50/P95 and SLO state.
4. It publishes JSON and CSV artifacts and a readable step summary.
5. The workflow self-tests on its own PR and remains schedule/manual capable after merge.
6. Project SLO documentation records budgets and explains soft-vs-hard enforcement.
7. Required repository CI and merge-group CI pass; change lands through protected merge queue.

## Verification

- PR run of `CI latency observability` succeeds and uploads report artifacts.
- Existing `CI result` succeeds for PR head and merge group.
- Inspect workflow summary for at least one measured fast-path sample.
- Verify canonical file on `main` after merge.

## Branch / PR

- Branch: `fcm/fab-p0003-finalize`
- PR: pending

## Implementation summary

Planned in this task stream.

## Evidence

Pending PR/workflow/merge evidence.

## Blockers / risks

- Historical runs may predate current job naming; such runs must be excluded or classified conservatively rather than corrupting metrics.
- Low sample counts must be reported explicitly; no fabricated percentiles.

## Next action

Implement the observer workflow and SLO documentation, then validate it in GitHub Actions.
