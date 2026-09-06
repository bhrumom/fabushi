# AAC-004 evidence — Mini App controlled Fabushi account session

Status: **IN_PROGRESS / PACKAGED_BOOTSTRAP_PENDING**

- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Current canonical main readback: `main@8595a50196309c8ebb91c3f8077125d7dc9e3ffa`.
- Current synchronized Web/service head: `a53b576ab99f0c3fbeed65e4e3937424d9abd3c6`; PR #2445 OPEN / MERGEABLE at readback.
- Web/service implementation: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Server-side protected Global Dharma runtime resolves a stable Fabushi account; account id, not a bearer token, owns durable runtime state.
- Integration contract covers two different valid sessions resolving to the same account and a separate account staying isolated.
- Entitlement/runtime response contracts do not serialize the supplied session token.
- Existing preferred bootstrap candidates: Electron `credential-gateway.cjs` (host-side credential injection + sensitive response-header redaction) and canonical five-minute `/v1/auth/plugin-token` / `auth.requestToken` issuer.
- Audit found no current consumer validation path for `PluginAccessTokenClaims`, so delegated-token automatic login is not marked complete.
- Required closure: packaged Host obtains/proxies a bounded credential without exposing raw Fabushi access/refresh token to Mini App JavaScript; logout/session revoke makes protected runtime/commerce unreadable; exact evidence includes CI test plus user-journey video/trace/logs.
- Exact-head account/runtime integration is green in Actions run `34047757146`, backend job `101525766224`, artifact `9993622901` (`sha256:0f737d7413cec0d81965b6ce64648b9a0586a7b403ae46615260f162fe2e3142`). This proves stable account scoping, same-account convergence, cross-account isolation, and token redaction at the Web/service boundary.
- It does **not** prove packaged automatic login or logout/revoke consumption. Related desktop #2448 still has a failing Global Dharma Electron journey, so AAC-004 remains `IN_PROGRESS / PACKAGED_BOOTSTRAP_PENDING`.
- Full packaged video is PENDING; no accepted-main AAC video link exists yet.
