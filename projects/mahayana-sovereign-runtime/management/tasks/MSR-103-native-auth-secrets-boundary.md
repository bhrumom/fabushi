# MSR-103 — Native auth and secrets boundary

- **Task ID:** MSR-103
- **Status:** in-progress
- **Started:** 2026-08-22T15:22:00+08:00
- **Updated:** 2026-08-22T15:43:00+08:00
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
`Mahayana fast checks` source-boundary, rustfmt, `cargo test -p mahayana-auth -p mahayana-secrets`, and `cargo test -p mahayana-platform-client`; Platform Control Plane `--locked`; Embedded Runtime / Global Dharma compatibility; merge-group CI; main source audit.

## Branch / commit / PR
Branch: `feat/mahayana-native-auth-boundary`
Current materialized head before this record sync: `d0cb8465d94a5f8133e0b0de568fe566097dda19`
PR: #1992

## Implementation summary
Introduced native authentication/JWT and encrypted secret-storage crates, registered them in the Mahayana workspace, rewired the product client's two historical source aliases to Mahayana packages, extended the source-boundary gate, and added dedicated CI tests. The aliases are private transitional spellings only; actual dependency resolution is Mahayana-owned.

The first CI rounds proved the source boundary and exposed two integration-only issues: rustfmt deltas and lockfile drift. The initial lock materialization succeeded, but GitHub's PR merge ref later included a newer `main` (`a2e2d8ddc7fd6ed720dec486546d080db3dba494`), so Embedded Runtime and Global Dharma correctly rejected the older branch lock under `--locked`. The branch was fast-forwarded to GitHub's exact synthetic merge commit `32b53d13034560bb0621a91fa30ab32b3302627b`, then the one-shot materializer was re-run against that synchronized tree.

Second materializer run `32560227491` passed and pushed `d0cb8465d94a5f8133e0b0de568fe566097dda19`. That commit removed the one-shot workflow and refreshed `Cargo.lock` for the synchronized dependency graph (including the `rusqlite` edge introduced on current main). Workflows emitted `action_required` on the bot-authored materializer commit, so this human/connector-authored project-record commit intentionally retriggers the normal required CI on the exact committed lockfile.

## Evidence
- PR: #1992.
- Source-boundary checks: passed in prior Fast Gate / Global Dharma rounds.
- Rustfmt-only failure: repaired before lock validation.
- First Platform Control Plane lock failure: run `32559989042`; root cause was missing materialized lock for new workspace crates.
- First materializer: run `32560073991`, success; lock commit `76d39d241552bc8dd5e1998968e9c98730dcb48a`.
- Merge-ref audit: `32b53d13034560bb0621a91fa30ab32b3302627b` merged branch head into current main `a2e2d8ddc7fd6ed720dec486546d080db3dba494`.
- Second materializer: run `32560227491`, success after main sync.
- Synchronized materialized lock commit: `d0cb8465d94a5f8133e0b0de568fe566097dda19`.
- One-shot workflow removed by its own successful materialization commit.
- Final ordinary CI / protected merge / main evidence: pending.

## Blockers / risks
The remaining blocker is objective CI on the connector-authored head that follows `d0cb8465...`. Any real compile/test/platform failure must be repaired before passing MSR-103.

## Next action
Run the normal Fast Gate, Platform, Embedded Runtime, Global Dharma, Electron and native-mobile checks against the synchronized committed lockfile; repair all failures, merge through protected main, and re-verify the product graph on canonical main.
