# 2026-08-28 — Credential Vault / last-hop injection source record

## User request

The user referenced Chris Maconi's X post:

- https://x.com/chrismaconi/status/2092383707349004788

and requested the same useful effect in Fabushi: a user should be able to give an Agent/API integration a credential without pasting it into chat or maintaining ad-hoc `.env` files; the model should use the credential without receiving its plaintext value.

This follows the preceding GBF efficient-run work: Agent routes should prefer Connector/MCP/API execution, and this task supplies a safe credential boundary for those routes.

## Existing Fabushi baseline

The repository already contains two important security primitives:

1. `third_party/mahayana/mahayana-rs/mahayana-secrets` stores secrets in age-encrypted files, protects the encryption key with the OS keyring, separates credential namespaces, and uses private file permissions.
2. Electron provider credentials already use `safeStorage` for Claude/OpenRouter, but the old Native Edge still exposed a `revealSecret` method and generic stored entries had no target binding.

The implementation therefore extends existing Fabushi security boundaries rather than introducing a second credential product.

## External architecture references

### CyberArk Secretless Broker

- Repository: https://github.com/cyberark/secretless-broker
- License: Apache-2.0
- Useful architecture idea: the application identifies the desired resource while a trusted broker retrieves the credential and injects it at connection establishment. The client never needs the credential value itself.
- Fabushi decision: learn from the broker pattern; do not add Secretless Broker as a runtime dependency.

### Electron safeStorage

- Documentation: https://www.electronjs.org/docs/latest/api/safe-storage
- Useful platform primitive: OS-backed encryption on supported desktop platforms.
- Fabushi decision: preserve the existing desktop provider-key compatibility store while enforcing non-revealability and target-bound use. Long-term canonical secret storage remains aligned with Mahayana's age + OS-keyring store.

## Clean-room behavior contract

Fabushi-owned implementation must satisfy all of the following:

- Plaintext credentials are never placed in model context, transcript content, ordinary tool arguments, persisted renderer state, structured logs or ordinary tool results.
- During explicit credential creation/rotation, plaintext exists transiently in the user's password input and the one native upsert invocation; after that invocation it is immediately cleared from React state and cannot be read back through the Renderer contract.
- Users and tools work with an opaque `SecretRef`, for example `connector/github/default`.
- `list` returns metadata only (`configured`, binding, timestamps); it never returns a value or a reversible preview.
- Existing plaintext reveal capability is removed from the Renderer Native Edge.
- A generic credential may not be used until it is explicitly bound to one or more exact HTTPS origins.
- Caller-provided `Authorization`, cookie, or API-key headers cannot override gateway injection.
- Credential-bearing redirects are not followed. A new target requires a separately authorized request.
- Credential values are decrypted and injected only inside the trusted desktop boundary at the final outbound request.
- Remote response bodies, response headers, status text and network-error messages are scrubbed for the raw credential and common encoded forms before crossing back to Renderer/model-facing surfaces. This protects against diagnostic/echo APIs reflecting request authentication.
- Rotation replaces ciphertext without changing the `SecretRef`; revocation removes the reference.
- Auditable metadata may include `SecretRef`, target origin, injection type and timestamp, but never the credential value.
- Existing Provider keys remain compatible but are not automatically promoted into generic Agent credentials.

## Product surface

The desktop Credential Vault is intentionally non-revealable after save. It supports:

- create;
- rotate;
- revoke;
- exact HTTPS origin binding;
- Bearer, custom-header and HTTP Basic injection metadata;
- last-used timestamp;
- event-driven opening so a future Connector/Skill/Workflow missing-credential card can deep-link into a prefilled SecretRef request.

The first Agent-facing production adapter in this slice is the desktop MiniApp/WebMCP host-owned `fabushi_credential_request` tool. It accepts only a scoped SecretRef plus request metadata and delegates final-hop credential use to the trusted Native gateway. Existing third-party MCP OAuth/native credential flows remain unchanged; this source record does not claim universal automatic SecretRef consumption by every MCP server.

## Acceptance boundary

Implementation work is tracked as `GBF-705`. It cannot be marked RELEASED from source code alone. Required closure includes the credential gateway unit/security suite, Native Edge parity, desktop typecheck/build, packaged E2E, protected-main verification, privacy/log scan, and exact-release evidence.
