# Runbooks — FAB-P0003

| Runbook | Purpose |
|---|---|
| `ci-latency-observation.md` | Inspect FCM-002 P50/P95, queue delay and raw Actions evidence |
| `store-release-source-gate.md` | Operate/recover Apple/Google exact-SHA release gating |

## Ownership

Fabushi maintainers own these procedures. GitHub Actions and protected `main` are the operational source of truth.

## N/A areas

Application incident response and application data repair are outside this CI/CD governance project's runtime scope. Revisit if this project later owns persistent release metadata or production runtime services.
