# Runbook — CI latency observation

## Purpose

Operate FCM-002 without turning telemetry into a merge dependency.

## Procedure

1. Open the latest `CI latency observability` workflow run.
2. Review the summary table by validation surface.
3. Download `fcm-ci-latency-<run_id>` artifact when raw evidence is needed.
4. Use `ci-latency-report.json` for machine-readable group metrics and `ci-latency-samples.csv` for per-run analysis.
5. If a group has fewer than five samples, treat `insufficient-samples` as informational.
6. If P95 is over budget, inspect queue delay first, then setup/install/cache/test duration in the underlying `CI` runs.
7. Optimize only redundant work; do not remove required safety gates to make the metric green.

## Failure handling

- Observer failure does not authorize a CI bypass.
- Repair the observer in a normal PR.
- Product `CI result` and merge queue remain authoritative for merge safety.

Last validated: pending PR #1999 acceptance.
