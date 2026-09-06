# TFI-WINDOWS-CI-SESSION-VALIDATOR-001 — Windows App-owned CI session validator

- Project: `FAB-P0001 / TFI`
- Parent: `TFI-WINDOWS-RELEASE-E2E-001`
- Status: `in-progress`
- Baseline: `main@74f92d67575650b6fe44686d777ed47865389edb`
- Branch: `fix/tfi-windows-ci-session-validator-20260907`
- Source: `projects/telegram-fabushi-integration/source/2026-09-07-windows-ci-session-validator.md`

## Objective

Repair the exact cross-layer allowlist drift that prevents a correctly exported refresh-token-free `gha-<run>-<attempt>-windows-app` session from bootstrapping the packaged Mahayana Host and therefore prevents App-owned Windows remote-device registration.

## Acceptance

- [ ] Rust `validate_ci_account_session` accepts exact `-windows-app` in addition to the already-approved `-interactive` and `-macos-app` suffixes.
- [ ] Existing GitHub Actions provenance, `provider=github-actions`, `ciRunner=true`, Bearer token, no-refresh-token, identity equality, bounded lifetime and private-file checks remain intact.
- [ ] Rust unit coverage proves a valid Windows App-owned bounded session succeeds.
- [ ] Node cross-layer contract proves the Rust validator contains the Windows suffix and does not replace the predicate with a broad device-id acceptance.
- [ ] Required PR checks pass on GitHub Actions; no local build/test is used.
- [ ] PR protected-merges through the native queue; canonical main is read back.
- [ ] A new exact-main Electron/package delivery exists for the resulting canonical SHA and produces a same-SHA immutable Release.
- [ ] A new Windows interactive job installs that Release, protected login/export succeeds, and the installed App itself reaches `controllable device online` with its fresh run-bound `windows-app` id.
- [ ] External `fabushi test` six semantic tools, full declared Windows journey and final `settings-logout` have truthful trace/video/screenshot/report/log evidence.
- [ ] Broader Global Dharma current-canonical acceptance remains PENDING until Marketplace search/install, Bot, Open App Web UI, WebMCP, same-revision sync, auto-login, and CNY1080 sandbox purchase/restore evidence is all present on the final canonical SHA.

## Diagnostic evidence

- Historical exact source `2bfa9898d453a91119f7dd9a072322970423cd6b` run/job: `34060996833 / 101561382562`.
- Same-SHA recovery Release resolution, install, protected login and bounded export all passed.
- Packaged Host failure: `CI account session failed its provenance, identity, or lifetime contract`.
- Failure evidence artifact: `9997771414`, SHA-256 `63399240dd7646dd962ca2b3cb851b75d7983785017fa8c0068f1efc25bdd40c`.
- Root-cause code mismatch: Node exact suffix sets already contain `windows-app`; Rust current validator contains only `-interactive || -macos-app`.

## Open-source-first decision

No generic dependency is applicable to this repository-specific security allowlist. Reuse the existing exact `-macos-app` validator pattern and existing Rust/Node tests; introduce no dependency or protocol.

## Next action

Patch only the Rust protected CI session predicate and its regression tests/contracts, then protected-merge and restart the delivery loop from the resulting canonical main.
