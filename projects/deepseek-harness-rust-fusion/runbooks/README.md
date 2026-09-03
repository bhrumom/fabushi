# Runbooks

## Capability migration runbook baseline
For each capability:
1. Reconstruct current state from this project and live `main`.
2. Confirm upstream pinned behavior and current Mahayana implementation.
3. Add/update the product-owned Rust contract before changing providers.
4. Implement or bridge behind an explicit capability/provider boundary.
5. Run required unit/contract/conformance/security checks in GitHub Actions.
6. Integrate only the supported product surfaces; capability-gate unsupported platforms explicitly.
7. Switch defaults only after acceptance evidence exists.
8. On regression, revert the provider/default switch while preserving compatible durable state and product-owned ABI.
9. Update task, WBS, acceptance, status, changelog, risks/dependencies and evidence in the same workstream.

## Upstream revision runbook
Do not move the DeepSeek Harness acceptance pin silently. Open a new audit task, record the new commit/version/date, diff capability/catalog/test changes, update source/changelog/matrix, then schedule only the new/changed gaps.
