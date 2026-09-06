# M8-WEBMCP-002 acceptance — Global Dharma shared runtime / commerce

State: `CURRENT_HEAD_CONTRACT_GREEN / MERGE_PENDING / PACKAGED_E2E_PENDING`

| Requirement | Acceptance evidence | Current state |
|---|---|---|
| Marketplace Chinese search/install | HTTP integration searches `全球法布施`, installs `global-dharma`, obtains `global_dharma_bot` | current-head run `34047757146` green |
| One Bot/WebMCP Tool Contract | canonical contract equals official `tools/list`; Marketplace commands derive from it; Bot invokes official MCP handler | current-head run `34047757146` green |
| Bidirectional shared state | account runtime revision + `as1` cursor; Bot mutation visible to official WebMCP; Web mutation visible to Bot | current-head run `34047757146` green |
| Disconnect recovery | difference replay + cursor-ahead snapshot recovery using existing AccountSync journal | current-head run `34047757146` green |
| Idempotency | same operationId/same semantics replays receipt; same key/different semantics fails 409 | current-head run `34047757146` green |
| Permission confirmation | WebMCP write/destructive confirmation retained; prayer-wheel Host request requires server entitlement allowed | current-head run `34047757146` green |
| AAC account boundary | protected runtime requires authenticated stable account; same-account sessions converge; other account isolated; raw token absent from runtime payload | partial — packaged credential bootstrap pending |
| CNY1080 lifetime entitlement | server catalog amount `108000`; canonical webhook/idempotency/refund/revocation/restore contracts | current-head contract green; live provider sandbox blocked |
| Packaged user journey | full video + checkpoint screenshots + trace/report/logs from accepted package | BLOCKED — no accepted package/provider sandbox evidence yet |
