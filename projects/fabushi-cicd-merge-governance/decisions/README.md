# Decisions

- `ADR-0001-risk-tiered-ci-merge-queue.md`: retain merge queue while selecting only the risk/impact-appropriate checks.
- `ADR-0002-ci-latency-observability.md`: measure latency from GitHub Actions metadata with soft SLOs rather than making telemetry a merge blocker.
- `ADR-0006-ordinary-device-build-isolation.md`: persistent/ordinary devices are low-footprint control/edit/deploy surfaces; all builds and disk-growing build caches are isolated to Actions/disposable runners.
