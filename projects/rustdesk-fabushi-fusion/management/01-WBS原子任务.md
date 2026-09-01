# 01 WBS 原子任务

| Task | Action | Dependency | Acceptance | Status | Next |
|---|---|---|---|---|---|
| RDF-001 | Unified account device presence slice | current account/remote-computer path | producer→D1/API→UI + CI | in-progress | implement schema/contracts/UI |
| RDF-002 | Provider/session abstraction | RDF-001 | provider-neutral session contract | planned | ADR/design |
| RDF-003 | Direct/relay negotiation | RDF-002 | direct-first + authenticated relay fallback | planned | threat model |
| RDF-004 | Desktop/display/input provider parity | RDF-003 | cross-platform conformance | planned | capability inventory |
| RDF-005 | Clipboard/file/audio/session parity | RDF-003 | bounded/resumable/permissioned E2E | planned | protocol matrix |
| RDF-006 | Policy/audit/recovery/release | RDF-001..005 | security + packaged E2E + Release | planned | evidence plan |
