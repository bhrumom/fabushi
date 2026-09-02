# 01 WBS 原子任务

| Task | Action | Dependency | Acceptance | Status | Next |
|---|---|---|---|---|---|
| RDF-001 | Unified account device presence slice | current account/remote-computer path | producer→D1/API→UI + CI | complete | merged PR #2272 + CI evidence |
| RDF-002 | Provider/session abstraction | RDF-001 | provider-neutral session contract | in-progress | provider binding CI-verified on #2275; merge queue + transport metadata contract |
| RDF-003 | Direct/relay negotiation | RDF-002 | direct-first + authenticated relay fallback | complete | Worker negotiation API + monotonic direct-to-relay fallback + audit verified in GitHub Actions |
| RDF-004 | Desktop/display/input provider parity | RDF-003 | cross-platform conformance | planned | capability inventory |
| RDF-005 | Clipboard/file/audio/session parity | RDF-003 | bounded/resumable/permissioned E2E | planned | protocol matrix |
| RDF-006 | Policy/audit/recovery/release | RDF-001..005 | security + packaged E2E + Release | planned | evidence plan |
