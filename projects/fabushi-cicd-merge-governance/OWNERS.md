# OWNERS — FAB-P0003

| Role | Owner | Responsibility |
|---|---|---|
| Accountable owner | Fabushi maintainers | CI/CD and merge governance outcomes |
| Execution owner | Repository engineering agents/maintainers | Implement, validate, document and merge governed changes |
| Sensitive-path reviewer | `@bhrum` | CODEOWNERS review target for CI/CD, release, payment/auth and this governance project |
| Consulted | Product-domain owners | Domain-specific quality and release constraints |

## Escalation

- Required CI failure: keep the task open and inspect the failing GitHub Actions job.
- Merge queue failure: fix/rebase/re-run through the queue; never bypass protected `main` for normal delivery.
- Release-source gate failure: do not upload; repair the missing canonical CI/platform gate or select a valid protected-main source commit.
- Credential/signing issues: treat as release operations blockers; never store secrets in project records.
