# MSR-103 — Native auth and secrets boundary

- **Task ID:** MSR-103
- **Status:** in-progress
- **Started:** 2026-08-22T15:22:00+08:00
- **Updated:** 2026-08-22T15:51:00+08:00
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
- Rust unit/product integration tests;
- compatibility-only dependency repair required to keep the existing Codex adapter buildable while native isolation proceeds.

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
8. Existing Codex compatibility adapter still passes locked cross-platform Embedded Runtime checks.
9. Protected merge completes and canonical main is re-verified.

## Verification
`Mahayana fast checks` source-boundary, rustfmt, `cargo test -p mahayana-auth -p mahayana-secrets`, and `cargo test -p mahayana-platform-client`; Platform Control Plane `--locked`; Embedded Runtime / Global Dharma compatibility; merge-group CI; main source audit.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Current bot materialized head before this record sync: `a9663be6d6846978fd92f1968ae778c67e2c1de2`
PR: #1992

## Implementation summary
Introduced native authentication/JWT and encrypted secret-storage crates, registered them in the Mahayana workspace, rewired the product client's two historical source aliases to Mahayana packages, extended the source-boundary gate, and added dedicated CI tests. The aliases are private transitional spellings only; actual dependency resolution is Mahayana-owned.

CI exposed three objective integration issues and each is being fixed at its source rather than bypassed:

1. Rustfmt-only changes were repaired.
2. New workspace members required an updated committed `Cargo.lock`; two one-shot materializers were used around moving-main synchronization and deleted themselves after successful lock commits.
3. Cross-platform Embedded Runtime Clippy exposed the legacy #1971 Rama graph defect: `rama-core 0.3.0-alpha.4` was resolving stable `rama-error 0.3.0`, which removed `OpaqueError`. The embedded Codex lock objectively pins `rama-error 0.3.0-alpha.4`. `mahayana-agent-codex` now pins exactly `rama-error = "=0.3.0-alpha.4"` at the compatibility adapter boundary only; Mahayana-native crates remain Rama-free. A narrow one-shot workflow then ran `cargo update -p rama-error --precise 0.3.0-alpha.4`, proved the resulting lock block matched the embedded Codex lock, deleted itself, and pushed the fixed lockfile.

## Evidence
- PR: #1992.
- Source-boundary checks passed in prior Fast Gate / Global Dharma rounds.
- Native `mahayana-auth` + `mahayana-secrets` Rust tests passed on ordinary CI before the Rama repair.
- Platform Control Plane `cargo test -p mahayana-platform-worker --locked` and production Worker compile passed after lock synchronization.
- First materializer run `32560073991`: success; lock commit `76d39d241552bc8dd5e1998968e9c98730dcb48a`.
- Second materializer run `32560227491`: success after moving-main sync; lock commit `d0cb8465d94a5f8133e0b0de568fe566097dda19`.
- Embedded Runtime failure log: `rama-core 0.3.0-alpha.4` could not import `rama_error::OpaqueError` because Mahayana lock had stable `rama-error 0.3.0`.
- Embedded Codex `Cargo.lock` proves compatible leaf is `rama-error 0.3.0-alpha.4`.
- Adapter manifest pin commit: `118f7429a430e6d4d87f91c624a686dadf253551`.
- Narrow Rama materializer run `32560629437`: success; exact-version update and lock self-check passed; temporary workflow removed.
- Rama lock materialized head: `a9663be6d6846978fd92f1968ae778c67e2c1de2`.
- Bot-head normal workflows were `action_required`; this connector-authored record sync intentionally retriggers ordinary required CI without changing runtime code.
- Final ordinary CI / protected merge / main evidence: pending.

## Blockers / risks
Objective CI on the connector-authored post-materializer head is the remaining MSR-103 blocker. Any actual compile/test/platform failure must be repaired before passing.

## Next action
Verify Fast Gate, Platform, Embedded Runtime, Global Dharma, Electron and native-mobile checks against the exact Rama-compatible committed lockfile; repair any real failure, merge via protected queue, and verify the product graph on canonical main.
