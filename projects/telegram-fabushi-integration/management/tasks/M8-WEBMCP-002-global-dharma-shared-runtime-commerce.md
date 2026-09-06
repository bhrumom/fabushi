# M8-WEBMCP-002 — Global Dharma shared WebMCP runtime + commerce journey

- Project: `FAB-P0001 / TFI`
- Stage: `M8 WebMCP + M9 payment integration`
- Status: `IN_PROGRESS`
- Started: `2026-09-06`
- Canonical base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Branch: `feat/tfi-global-dharma-web-service-sync-pay-20260906`
- Source: `../../source/2026-09-06-global-dharma-web-service-sync-commerce.md`
- Cross-project dependency: `FAB-P0008/AAC-004`

## Objective

Close the Web/server authority boundary for the official `global-dharma` Mini App so Marketplace/Bot/WebMCP use one Tool Contract, Bot and graphical Mini App observe the same durable account-scoped runtime, authenticated users receive a bounded server-side session projection, and the CNY 1080 lifetime prayer-wheel purchase/restore path consumes canonical Fabushi Pay rather than client-local state.

## Atomic acceptance

### A. Canonical Tool Contract
- One source defines Global Dharma tool names, descriptions, annotations/approval metadata and natural-language hints.
- Official MCP `tools/list`, Marketplace manifest commands and Mini App Bot command projection are derived from that source.
- Contract test fails if Marketplace/Bot inventory drifts from live MCP inventory.

### B. Durable account-scoped runtime
- Global Dharma `mode/running/loops/sent/logs/pendingContent` is persisted through existing `AccountSyncStore`, not process-local `Map` authority.
- Every mutation has a monotonic account event sequence/cursor and runtime revision.
- Initial state, difference replay, cursor-ahead/expired snapshot recovery and account isolation are objectively tested.

### C. Idempotency + approval
- Mutating tool calls carry a stable operation/idempotency identity.
- Same key + same operation/arguments replays the original receipt without duplicate side effect.
- Same key + different operation/arguments fails closed.
- read/write/open-world/destructive metadata remains explicit; WebMCP UI cannot silently skip required user confirmation.

### D. Bot / Web UI bidirectional convergence
- Bot natural-language routing resolves only against the current canonical Global Dharma Tool Contract.
- Bot-triggered tool mutation is visible when the Web UI opens and the Web UI receives later mutations through the same durable sequence.
- Reconnect from an old cursor deterministically catches up without a second event authority.
- `tools/list` and `tools/call` evidence is captured in contract/integration tests.

### E. Commerce / entitlement
- Lifetime product is server-authoritative CNY `108000` minor units and protects exact capability `local.prayer-wheel.start`.
- Web/server integration reuses canonical Fabushi Pay PaymentIntent/Order/provider verification/webhook/refund/reconciliation/entitlement APIs.
- Duplicate provider callback/idempotency key cannot duplicate capture/ledger/entitlement.
- Refund/reversal revokes or denies access according to canonical entitlement state; restore/reconciliation re-reads server authority.
- No Mini App local flag or raw payment state can authorize the host capability.

### F. Objective evidence / delivery
- Fast contract tests: Global Dharma Tool Contract parity, runtime idempotency/replay, account isolation, auth/session redaction, payment facade/entitlement contract.
- Integration test: Marketplace search/install -> Bot route -> MCP tools/list/tools/call -> runtime difference/reconnect -> entitlement read.
- Heavy/package/provider validation only through GitHub Actions.
- Protected PR merge + canonical-main readback required.
- Final packaged-user journey must retain full video, meaningful checkpoint screenshots, trace/report/logs and a real downloadable artifact link. If provider sandbox/package/device is unavailable, task remains BLOCKED/IN_PROGRESS and records the exact dependency.

## Known baseline and stale records

- PR #2169 (`M8-WEBMCP-001`) is already merged as `fefb35fc8a4e5c8dabecc9c11803764ec950b6e9`; old task/WBS pre-merge wording must be corrected in this round.
- PR #2135 (`M9-GLOBAL-DHARMA-003` Round A) is already merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`; Round B Host/Web integration and packaged payment/restore evidence remain open.
- M2 account sync already provides durable `as1:<sequence>` difference/snapshot recovery and is the required event substrate.

## Evidence

- Intake source commit: `2eb4b0cf524942f003bc6ec973ba8119745b2030`.
- Implementation PR / CI / packaged evidence: pending this task.

## Blockers

- Real production/sandbox payment provider credentials and KYC/provider activation are external; tests must fail closed if absent.
- Packaged-user video depends on an installable release/Actions device lane and is not considered complete until a real artifact exists.
