# AAC-004 evidence — Mini App controlled Fabushi account session

Status: **IN_PROGRESS / DESKTOP_PREPACKAGE_GREEN / ACCEPTED_MAIN_PACKAGE_AND_ANDROID_TERMINAL_PENDING**

- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Current canonical main readback: `main@380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`.
- Current synchronized Web/service head: `a53b576ab99f0c3fbeed65e4e3937424d9abd3c6`; PR #2445 OPEN / MERGEABLE at readback.
- Web/service implementation: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Server-side protected Global Dharma runtime resolves a stable Fabushi account; account id, not a bearer token, owns durable runtime state.
- Integration contract covers two different valid sessions resolving to the same account and a separate account staying isolated.
- Entitlement/runtime response contracts do not serialize the supplied session token.
- Existing preferred bootstrap candidates: Electron `credential-gateway.cjs` (host-side credential injection + sensitive response-header redaction) and canonical five-minute `/v1/auth/plugin-token` / `auth.requestToken` issuer.
- Historical audit note superseded: #2445 added the server consumer validation/introspection path for `PluginAccessTokenClaims`; packaged terminal proof remains separate.
- Required closure: packaged Host obtains/proxies a bounded credential without exposing raw Fabushi access/refresh token to Mini App JavaScript; logout/session revoke makes protected runtime/commerce unreadable; exact evidence includes CI test plus user-journey video/trace/logs.
- Exact-head account/runtime integration is green in Actions run `34047757146`, backend job `101525766224`, artifact `9993622901` (`sha256:0f737d7413cec0d81965b6ce64648b9a0586a7b403ae46615260f162fe2e3142`). This proves stable account scoping, same-account convergence, cross-account isolation, and token redaction at the Web/service boundary.
- It does **not** prove packaged automatic login or logout/revoke consumption. Related desktop #2448 still has a failing Global Dharma Electron journey, so AAC-004 remains `IN_PROGRESS / PACKAGED_BOOTSTRAP_PENDING`.
- Full packaged video is PENDING; no accepted-main AAC video link exists yet.

## 2026-09-07 verified closure evidence

- #2445: head `7ec44b0b000e25ceb8799843cf98f85f3c6aa9b6` -> merge `c82b29cd6404c2f19b93d8479b2e2cae45469249`; target run `34049805438` SUCCESS; merge queue `34049934041` SUCCESS.
- Web/service artifacts: `9994199494` (`sha256:f7e4ca191e514d3fb4a75d5f6c319453659400188eabc13ed0f79614387578a3`), `9994192661` (`sha256:26c508ff77041a4daafa947bac447f2be320ca948df66d09d82ed2af54c8c805`), `9994207785` (`sha256:4f88acd4de6f62dd94c262104087036beb70f001177e15a45de44257836ac835`).
- Desktop pre-package Host evidence: run `34051925481`, artifact `9994834346` (`sha256:1bf06fa2d3a6dc308a118ea173a392ece92049dfb1053cf78fb9331445ea3e14`). Inside: 12 checkpoint PNGs, Global Dharma WebMCP/payment/logout `trace.zip` (`sha256:b0f83cf852c19b3d8be72045c5c203dbd8d079d52c6f4e30d55780801f8971f0`) and complete requested journey video through entitled prayer-wheel/UI parity (`sha256:3afde68f3855faf4c7b3bf2e1e363866ab7f609ef8442037566f0f1cabb3c7b8`). This run is pre-package, so accepted-main installable evidence remains pending.
- Android exact release `1.2.52-262491811@380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab` succeeded in run `34050780156`, artifact `9994614114`. Interactive run `34051316405` artifact `9994884584` (`sha256:dfad88db72093413f625963f1f9ff7898266e81a9211a09b41d99cc304d3d852`) proves APK install, App-owned registration and partial six-tool control, but report `failed-timeout` (`sha256:3410cbef8b7e74ea1c34e915a66eac9a429cd2ad713e67c44b8750f92a64e10c`) after connection refresh failure; no terminal logout or single stitched Android session video exists.
