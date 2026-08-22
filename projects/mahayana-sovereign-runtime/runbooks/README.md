# Runbooks

## Migration runbook baseline
For each capability migration:
1. Pin source revision and map behavior/provenance.
2. Define/confirm Mahayana-owned contract.
3. Implement native behavior or adapter behind that contract.
4. Add conformance/security tests.
5. Wire one product surface at a time.
6. Validate in GitHub Actions.
7. Switch default path only after evidence passes.
8. Keep rollback adapter until post-merge verification proves stability.
9. Remove compatibility code only in a separate evidence-backed step.

No local heavy build/test is permitted by repository policy.
