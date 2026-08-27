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

- The model, transcript, Renderer, logs and ordinary tool results never receive plaintext credentials.
- Users work with an opaque `SecretRef`, for example `connector/github/default`.
- `list` returns metadata only (`configured`, binding, timestamps); it never returns a value or a reversible preview.
- Existing plaintext reveal capability is removed from the Renderer Native Edge.
- A generic credential may not be used until it is explicitly bound to one or more exact HTTPS origins.
- Caller-provided `Authorization`, cookie, or API-key headers cannot override gateway injection.
- Credential-bearing redirects are not followed. A new target requires a separately authorized request.
- Credential values are injected only inside the trusted desktop boundary at the final outbound request.
- Rotation replaces ciphertext without changing the `SecretRef`; revocation removes the reference.
- Auditable metadata may include `SecretRef`, target origin, injection type and timestamp, but never the credential value.
- Existing Provider keys remain compatible but are not automatically promoted into generic Agent credentials.

## Product surface

The desktop Credential Vault is intentionally non-revealable. It supports:

- create;
- rotate;
- revoke;
- exact HTTPS origin binding;
- Bearer, custom-header and HTTP Basic injection metadata;
- last-used timestamp;
- event-driven opening so a future Connector/Skill/Workflow missing-credential card can deep-link into a prefilled SecretRef request.

## Acceptance boundary

Implementation work is tracked as `GBF-705`. It cannot be marked RELEASED from source code alone. Required closure includes the credential gateway unit/security suite, Native Edge parity, desktop typecheck/build, packaged E2E, protected-main verification, privacy/log scan, and exact-release evidence.
