# MSR-103 — Native auth and secrets boundary

- **Task ID:** MSR-103
- **Status:** in-progress
- **Started:** 2026-08-22T15:22:00+08:00
- **Updated:** 2026-08-22T15:26:00+08:00
- **Completed:** null

## Objective
Remove `mahayana-product`'s runtime dependency on Codex login/secrets implementations while preserving account-session behavior, encrypted data compatibility, and existing installations.

## Source requirements
MSR-R01, MSR-R02, MSR-R05, MSR-R06, MSR-R07; PR #1971 migration boundary.

## In scope
- Mahayana-owned JWT expiry parsing;
- Mahayana-owned encrypted secret storage;
- dedicated Mahayana OS-keyring services;
- migration of historical managed-secret encryption keys from the `codex` keyring service;
- preservation of `local.age` / `mahayana_auth.age` encrypted-file compatibility;
- strict file/directory permissions and atomic replacement;
- product dependency cutover and CI source-boundary enforcement;
- Rust unit/product integration tests.

## Out of scope
Codex agent compatibility adapter removal; that is MSR-601 after native agent parity.

## Dependencies
MSR-102 capability mapping.

## Acceptance criteria
1. `mahayana-auth` and `mahayana-secrets` are first-party workspace crates with no Codex/xAI imports.
2. `mahayana-product` no longer resolves login/secrets to upstream packages or paths.
3. Existing Mahayana auth encrypted file/keyring naming remains compatible.
4. Existing managed `local.age` data can read the historical `codex` encryption key and migrate that opaque key to `mahayana-managed-secrets` without rewriting secret payloads.
5. Secret files are encrypted, atomically replaced, and hardened to 0600/0700 where supported.
6. Source-boundary guard rejects a product alias that points back to upstream paths or any new vendor-style import.
7. GitHub Actions pass native auth/secrets tests and compile/test `mahayana-platform-client` against the native crates.
8. Protected merge completes and canonical main is re-verified.

## Verification
`Mahayana fast checks` source-boundary, rustfmt, `cargo test -p mahayana-auth -p mahayana-secrets`, and `cargo test -p mahayana-platform-client`; merge-group CI; main source audit.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Commit: pending final head
PR: pending

## Implementation summary
Introduced native authentication/JWT and encrypted secret-storage crates, registered them in the Mahayana workspace, rewired the product client's two historical source aliases to Mahayana packages, extended the source-boundary gate, and added dedicated CI tests. The aliases are private transitional spellings only; actual dependency resolution is Mahayana-owned.

## Evidence
To be indexed under `evidence/MSR-103/` after CI/merge.

## Blockers / risks
CI has not yet run on the active PR. Cargo/API/platform incompatibilities must be repaired from Actions evidence before this task can pass.

## Next action
Open PR, inspect Actions, repair all failures, merge via protected queue, then verify the product graph on main.
