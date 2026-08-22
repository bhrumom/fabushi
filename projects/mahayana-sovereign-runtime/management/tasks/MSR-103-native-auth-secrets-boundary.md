# MSR-103 — Native auth and secrets boundary

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-103
- **Status:** in-progress
- **Started:** 2026-08-22T15:22:00+08:00
- **Updated:** 2026-08-22T17:03:00+08:00
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
- compatibility-only dependency repair required to keep the audited Codex adapter buildable while native isolation proceeds.

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
`Mahayana fast checks` source-boundary, rustfmt, `cargo test -p mahayana-auth -p mahayana-secrets`, and `cargo test -p mahayana-platform-client`; Platform Control Plane `--locked`; Embedded Runtime / Global Dharma compatibility; Electron/native-mobile quality gates where triggered; merge-group CI; main source audit.

## Branch / commit / PR
Branch: `feat/msr-103-native-auth-secrets-clean`
Current implementation head before this record sync: `90d657b4db5b009967780cba83890997cffbbcb8`
PR: #2000
Superseded polluted stream: #1992

## Implementation summary
Introduced native authentication/JWT and encrypted secret-storage crates, registered them in the Mahayana workspace, rewired the product client's two historical source aliases to Mahayana packages, extended the source-boundary gate, and added dedicated CI tests. The aliases are private transitional spellings only; actual dependency resolution is Mahayana-owned.

The clean #2000 stream was recreated from canonical `main` to exclude unrelated Telegram files and one-shot diagnostics from #1992. Objective CI then exposed and repaired two compatibility issues:

1. Rust 1.98 Clippy required `LocalSecretsNamespace::default` to use `#[derive(Default)]` with an explicit `#[default]` variant; the native secrets implementation now follows that rule.
2. `rama-core 0.3.0-alpha.4` permits semver resolution of sibling pre-release crates, so Cargo had mixed `rama-http 0.3.0-alpha.4` with stable `rama-macros`/`rama-utils 0.3.0`. The audited embedded Codex lock pins the whole Rama family to alpha.4. At the explicit `mahayana-agent-codex` compatibility boundary, `rama-error`, `rama-macros` and `rama-utils` are now pinned exactly to `0.3.0-alpha.4`, and the Mahayana lock has been materialized to those versions. Mahayana-native crates remain Rama-free.

## Evidence
- Clean PR: #2000.
- Initial clean implementation commit: `5dd65736d09ae80331beef5ade6544d2ae94f2fb`.
- Clean evidence/lock synchronization commit: `16cc7049801d66801f43a9b516fd7a8c5c94f5ca`.
- Exact Rama compatibility manifest pin commit: `ebcfb752c6b527a2af367b64ad71b657213e9926`.
- One-shot materializer trigger: `44fb366a15af7fcd64fbc03b5eee7fd006f87691`.
- Materialized repair head: `90d657b4db5b009967780cba83890997cffbbcb8`; the temporary workflow self-deleted after materializing the Clippy and lock repairs.
- `Cargo.lock` now records `rama-macros = 0.3.0-alpha.4` and `rama-utils = 0.3.0-alpha.4`, matching the audited embedded Codex lock family.
- Earlier exact-head Platform Control Plane passed before the final materializer; final trusted connector-authored CI round is being retriggered by this record sync.
- Final ordinary CI / protected merge / canonical-main evidence: pending.

## Blockers / risks
Objective CI on the connector-authored post-materializer head is the remaining MSR-103 blocker. Any actual compile/test/platform failure must be repaired before passing.

## Next action
Verify Fast Checks, Platform, Embedded Runtime, Global Dharma, messaging, Electron and native-mobile checks against the exact materialized repair; repair any real failure, merge #2000 through the protected path, and verify the product graph on canonical `main`.
