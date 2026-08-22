# MSR-103 — Native auth and secrets boundary

- **Task ID:** MSR-103
- **Status:** in-progress
- **Started:** 2026-08-22T15:22:00+08:00
- **Updated:** 2026-08-22T15:39:00+08:00
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
`Mahayana fast checks` source-boundary, rustfmt, `cargo test -p mahayana-auth -p mahayana-secrets`, and `cargo test -p mahayana-platform-client`; Platform Control Plane `--locked`; merge-group CI; main source audit.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Current implementation head before this record sync: `76d39d241552bc8dd5e1998968e9c98730dcb48a`
PR: #1992

## Implementation summary
Introduced native authentication/JWT and encrypted secret-storage crates, registered them in the Mahayana workspace, rewired the product client's two historical source aliases to Mahayana packages, extended the source-boundary gate, and added dedicated CI tests. The aliases are private transitional spellings only; actual dependency resolution is Mahayana-owned.

A first PR CI round proved the source-boundary guard and exposed two objective integration issues: rustfmt-only changes and a stale workspace lockfile in an existing `--locked` Platform Control Plane test. The format delta was repaired. A one-shot, same-repository PR materializer then ran as workflow `Mahayana auth lockfile materialize once` / run `32560073991`, generated the exact Cargo dependency graph, removed its own workflow file, and pushed commit `76d39d241552bc8dd5e1998968e9c98730dcb48a` containing the updated `Cargo.lock`. The normal CI suite is now being retriggered against the committed lockfile.

## Evidence
- PR: #1992.
- First fast-gate source-boundary check: passed.
- First fast-gate formatter failure: repaired in `c6bc869a8ea249306143a54e688a7b9aa8b32dea` / `d3f557e0ffe15898830a39b87e1126e3efc7f12e`.
- Platform Control Plane run `32559989042`: failed only because `cargo test -p mahayana-platform-worker --locked` detected an unmaterialized lockfile.
- One-shot lock materializer run `32560073991`: success; generated lockfile and deleted its own workflow before commit.
- Materialized lockfile commit: `76d39d241552bc8dd5e1998968e9c98730dcb48a`.
- Final CI/merge/main evidence: pending.

## Blockers / risks
Normal CI against the committed lockfile is now pending. Any Cargo/API/platform incompatibilities revealed next must be repaired before this task can pass.

## Next action
Inspect the retriggered Fast Gate and Platform/Electron/mobile/embedded-runtime checks, repair all failures, merge via protected queue, then verify the product graph on canonical main.
