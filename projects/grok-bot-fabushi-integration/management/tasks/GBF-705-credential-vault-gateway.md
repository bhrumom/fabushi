# GBF-705 — Credential Vault and last-hop injection

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-705`
- Stage: `M7`
- Status: `IN_PROGRESS`
- Started: `2026-08-28`
- Branch: `feat/gbf-credential-vault-gateway`
- Source record: `source/2026-08-28-credential-vault-last-hop-injection.md`

## Objective

Implement a Fabushi-owned, non-revealable-after-save Credential Vault and a shared `SecretRef`/last-hop gateway contract that Agent, Connector, MCP, Skill and Workflow integrations can adopt without placing credentials in model/tool arguments. The first production adapter in this slice is the installed MiniApp/WebMCP path; existing third-party MCP OAuth/native credential flows remain intact and are not misrepresented as already migrated.

This task must reduce secret exposure; it must not create a second Agent runtime or a second unrelated credential authority.

## Dependencies

- GBF-303 — canonical tool/MCP dispatch.
- GBF-406 — sensitive-input security boundary.
- GBF-603/704 — structured log/privacy closure for final RELEASED status.
- Existing `mahayana-secrets` age + OS-keyring architecture and Electron `safeStorage` provider compatibility layer.

## Required behavior

1. **Opaque references** — after credential creation/rotation, product/tool contracts use `SecretRef`, never plaintext values.
2. **Write-only-after-save UI** — users may create, rotate and revoke credentials; saved plaintext cannot be displayed again. The password input necessarily holds the user-entered value transiently until the native upsert call completes, then React state is cleared.
3. **Metadata-only listing** — list returns configuration/binding/timestamps only.
4. **No Renderer reveal** — `revealSecret` is absent from both CJS and TypeScript Native Edge contracts.
5. **Target binding** — generic credentials require exact HTTPS origins before use.
6. **Last-hop injection** — Authorization/API-key material is injected inside the trusted desktop gateway, not by model/tool arguments.
7. **No auth override** — callers cannot supply competing Authorization/cookie/API-key headers to a credentialed request.
8. **Redirect isolation** — credentialed requests use manual redirects; credentials never automatically follow Location targets.
9. **Response/error scrubbing** — echoed credential material in body, response headers, status text or network errors is removed before results cross back to model/Renderer-facing surfaces.
10. **Rotation/revocation** — rotating preserves the stable reference; revocation invalidates it.
11. **Audit-safe metadata** — last-used time, target origin and injection type may be recorded; credential values may not.
12. **Legacy compatibility** — existing Provider keys continue to work but remain unbound to generic tools until explicitly configured.
13. **Shared product entry point** — the vault can be opened directly and by a future missing-credential request event with a prefilled reference/binding.
14. **Plugin namespace isolation** — the MiniApp/WebMCP credential adapter can request only `connector/<pluginId>/...` or `plugin/<pluginId>/...` references matching the installed plugin identity.

## Implementation slice

- `desktop/electron/credential-gateway.cjs`
  - wraps the existing native capability factory;
  - keeps the existing encrypted provider store format compatible;
  - changes list semantics to metadata-only;
  - blocks plaintext reveal;
  - adds exact-origin credential injection with strict request/response limits;
  - scrubs reflected credential material from successful and failed network results.
- `desktop/electron/bootstrap.cjs`
  - installs the credential-aware native capability wrapper before loading canonical `main.cjs`.
- `desktop/electron/native-edge.cjs`
- `desktop/src/edge/contracts/native-capabilities.ts`
  - remove plaintext reveal from the Renderer surface.
- `desktop/src/credential-vault.tsx`
- `desktop/src/credential-vault-model.ts`
- `desktop/src/credential-vault.css`
  - product UI for create/rotate/revoke and target/injection metadata.
- `desktop/src/miniapp-webmcp-host.ts`
  - exposes host-owned `fabushi_credential_request` to installed MiniApps;
  - scopes SecretRefs to the installed plugin identity;
  - prompts for write-type HTTP methods and delegates final-hop injection to the trusted gateway.
- `desktop/electron/credential-gateway.test.cjs`
  - canary-secret leak, response/error echo, target binding, HTTP/cross-origin/header override and compatibility tests.
- `desktop/electron/edge-ipc.test.cjs`
  - makes the credential suite part of the existing required Electron contract test invocation and asserts the reveal method is absent.
- `desktop/e2e/credential-vault.spec.ts`
  - installed-app create/list/no-reveal/rotate/revoke user journey using synthetic credentials.

## Security notes

- Test credentials are synthetic canaries only. No real token/API key is committed or logged.
- Generic credentials without target bindings fail closed.
- The current compatibility store uses Electron `safeStorage`; the repository's stronger canonical Mahayana secret store remains age-encrypted + OS keyring. A later migration may move compatibility ciphertext into that canonical store without changing the public `SecretRef` contract.
- The first implementation must not falsely claim that every existing third-party MCP server automatically consumes `SecretRef`. Existing OAuth/native credential flows continue unchanged; new/generic credential-aware tool flows must use the last-hop gateway contract.
- It is also incorrect to claim that the UI Renderer never transiently sees the value a user is actively typing. The enforced guarantee is that plaintext does not enter model context/transcript/tool arguments/logs/persisted Renderer state and cannot be read back after save.

## Verification required

- Node credential gateway unit/security suite.
- Existing Native Edge parity + architecture guards.
- Desktop TypeScript check and renderer build.
- Packaged Electron journey: create -> list metadata -> rotate -> revoke, plus bound-request security coverage; inspect screenshot/video/trace.
- Log/privacy scan proves canary plaintext absent from renderer logs, trace metadata and stored JSON after submission.
- Protected PR/main verification and exact-release package evidence.

## Current evidence

Implementation is present on the task branch. CI, packaged E2E, protected-main and Release evidence are not yet complete, therefore status remains `IN_PROGRESS`.

Evidence index: `evidence/GBF-705/README.md`.
