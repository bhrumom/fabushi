# M1-ACCEPT-001 — M1 Rust Core stage closure

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M1-ACCEPT-001`
- **Stage**: `M1 Rust Core 骨架`
- **Status**: `TESTED`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Completed**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M1.md`

## Objective

Close the M1 stage only after the canonical Rust messaging core, durable SQLite production storage, and Electron/Feature Host bridge are all verified by current-head GitHub Actions and the production storage cutover is present on canonical `main`.

## Acceptance criteria and result

1. Canonical Messaging Protocol v2 and the Rust messaging state machine compile and pass all-target messaging tests — **PASS**.
2. Production state is authoritative in SQLite and can recover persisted state — **PASS**.
3. Legacy JSON import is one-time only and cannot overwrite existing SQLite state — **PASS**.
4. Feature Host bridge consumes the same canonical messaging core rather than a second state machine — **PASS**.
5. Electron Messenger contract and Native Edge parity checks pass — **PASS** for the M1 desktop/host baseline; full iOS/Android cross-device acceptance remains M11.
6. Required repository/project governance checks pass for the clean production cutover — **PASS**.
7. Production SQLite cutover is merged and re-read on canonical `main` — **PASS**.

## GitHub evidence

- PR #1988 — SQLite schema/storage foundation; merge `1b78e4fbc1a666fc725c21450b11d3ab643ac0fa`.
- PR #1998 — clean current-main production SQLite cutover; merge `6ad86ccc809a6f00130888087f22cbb201e853fd`.
- Messaging Product Gate run `32563424543` — SUCCESS.
  - `Rust self-hosted product`: rustfmt, messaging library/server binary tests, Clippy, Feature Host bridge/contact projection all SUCCESS.
  - `Electron Messenger contract`: Feature Host architecture, signaling endpoint policy, Native Edge parity and Messenger V2 typecheck all SUCCESS.
- Mahayana fast checks run `32563424539` — SUCCESS.
- Repository CI run `32563424556` — SUCCESS.
- Project portfolio governance run `32563424574` — SUCCESS.
- Self-hosted messaging run `32563424511` — SUCCESS.
- Canonical `main` re-read confirmed `MessagingTcpServer` uses `SqliteStateStore` and performs legacy JSON import only while SQLite is empty.

## Scope boundary

This closes the M1 foundation at `TESTED`. It does not claim M2 reconnect/delta semantics, mobile cross-device E2E (M11), advanced feature-domain E2E (M3-M13), or legacy-stack deletion (M14).

## Evidence index

`../../evidence/M1-ACCEPT-001/README.md`
