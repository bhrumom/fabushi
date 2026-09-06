# AAC-004 evidence — Mini App controlled Fabushi account session

Status: **IN_PROGRESS / PACKAGED_BOOTSTRAP_PENDING**

- Canonical base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Web/service implementation: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Server-side protected Global Dharma runtime resolves a stable Fabushi account; account id, not a bearer token, owns durable runtime state.
- Integration contract covers two different valid sessions resolving to the same account and a separate account staying isolated.
- Entitlement/runtime response contracts do not serialize the supplied session token.
- Existing preferred bootstrap candidates: Electron `credential-gateway.cjs` (host-side credential injection + sensitive response-header redaction) and canonical five-minute `/v1/auth/plugin-token` / `auth.requestToken` issuer.
- Audit found no current consumer validation path for `PluginAccessTokenClaims`, so delegated-token automatic login is not marked complete.
- Required closure: packaged Host obtains/proxies a bounded credential without exposing raw Fabushi access/refresh token to Mini App JavaScript; logout/session revoke makes protected runtime/commerce unreadable; exact evidence includes CI test plus user-journey video/trace/logs.
