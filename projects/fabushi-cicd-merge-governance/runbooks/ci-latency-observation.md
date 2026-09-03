# Runbook — CI latency observation

## Purpose

Operate FCM-002 without turning telemetry into a merge dependency.

## Procedure

1. Open the latest `CI latency observability` workflow run.
2. Review the summary table by validation surface.
3. Download `fcm-ci-latency-<run_id>` when raw evidence is needed.
4. Use `ci-latency-report.json` and `ci-latency-samples.csv` for analysis.
5. Fewer than five samples means `insufficient-samples`, not fabricated SLO success/failure.
6. If P95 is over budget, inspect queue delay first, then setup/install/cache/test duration.
7. Optimize redundant work only; never remove required safety gates to make telemetry green.

## Failure handling

Observer failure does not authorize a CI bypass. Repair the observer via protected PR; product `CI result` and merge queue remain authoritative.

Last validated: 2026-08-22, observer run `32564046852` / PR #1999.
