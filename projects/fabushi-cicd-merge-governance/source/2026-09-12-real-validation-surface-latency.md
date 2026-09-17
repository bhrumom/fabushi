# 2026-09-12 — Measure real validation-surface latency

Project: `FAB-P0003 / FCM`
Task: `FCM-010.11`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Finding

The existing CI latency observer was no longer aligned with the repository's current feedback architecture. It queried only `.github/workflows/ci.yml` while classifying runs by historical job names (`Frontend checks`, `Worker checks`, `MCP plugin contracts`, `Canonical architecture guardrails`, `Electron Feature Host contract`). The current required `ci.yml` is a single lightweight `CI result` job, while Mahayana, Electron, Native and packaged macOS validation live in separate workflows.

Therefore a successful latency-observability run did not mean the current CLI/UI split was actually being measured end to end.

## Decision

Measure workflow surfaces directly instead of inferring architecture from stale job names. Keep a 14-day window and separate queue time from execution time. Report P50/P95 and a soft per-surface SLO for the current fast and canonical paths, plus the slowest individual samples.

The observer remains non-blocking for SLO misses. Correctness, security, packaged E2E and release gates remain authoritative; latency data identifies where the next optimization should go.
