# 2026-09-07 — Windows App-owned CI session validator drift

- Project: `FAB-P0001 / TFI`
- Parent task: `TFI-WINDOWS-RELEASE-E2E-001`
- Baseline: protected canonical `main@74f92d67575650b6fe44686d777ed47865389edb`
- Discovery evidence source: exact historical run `34060996833` from `2bfa9898d453a91119f7dd9a072322970423cd6b`; this run is diagnostic only and cannot close final current-main acceptance.

## User requirement carried forward

The final protected canonical SHA must own the real Release and truthful packaged evidence: Windows/macOS interactive terminal results, full-session video, step screenshots, trace/report/logs, and the Global Dharma Mini App journey covering Marketplace search/install, Bot, Open App Web UI, natural-language WebMCP, Bot/UI same revision, bounded Fabushi automatic login, and sandbox CNY 1080 lifetime purchase/restore. Historical-SHA evidence is never a completion substitute.

## Exact failure

Windows interactive run `34060996833`, job `101561382562`, successfully:

- bound Release `desktop-1.2.53-2bfa9898d453` to exact source `2bfa9898...`;
- installed `fabushi-1.2.53-setup.exe` / app version `1.2.53.0`;
- authenticated the protected CI test account;
- exported the refresh-token-free bounded App session.

The packaged App then failed App-owned registration within 120 seconds. Its App Agent Surface started, but the Mahayana Host repeatedly failed initialization with:

`Mahayana account session failed: CI account session failed its provenance, identity, or lifetime contract`

The always-upload evidence artifact is `9997771414` (`fabushi-windows-interactive-evidence-34060996833-1`, ~121 MB, SHA-256 `63399240dd7646dd962ca2b3cb851b75d7983785017fa8c0068f1efc25bdd40c`). Its report records exact source/release binding, `sessionOutcome=failure`, `controlStatus=not-run`, `playwrightOutcome=skipped`, and zero completed semantic tools. The whole-session MP4 is non-empty (~400 seconds).

## Root cause proven from current source

The JS protected-account layers are already aligned:

- `chatgpt-vps-control/scripts/export-ci-app-account-session.mjs` accepts exact IDs matching `gha-<run>-<attempt>-(interactive|ios-app|macos-app|windows-app)` and emits `provider=github-actions`, `ciRunner=true`, `sessionId=ci-runner:<run>:<attempt>`, exact `deviceId`, and no refresh token.
- `chatgpt-vps-control/lib/fabushi-account-session.js` uses the same exact protected-device suffix set.

But `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs::validate_ci_account_session` still accepts only:

`device_id.ends_with("-interactive") || device_id.ends_with("-macos-app")`

Therefore every correctly exported `gha-...-windows-app` session is deterministically rejected before the packaged Host can produce the account-scoped remote-device registration.

## Smallest repair boundary

1. Add only exact suffix `-windows-app` to the existing Rust CI session device predicate.
2. Add a Rust unit case proving a valid bounded Windows App-owned session passes while existing wrong-device, refresh-token, identity, and lifetime failures remain fail-closed.
3. Extend the dependency-free cross-layer account-binding contract to require the Rust validator to recognize `-windows-app`.
4. Do not change credentials, session prefix, provider, token lifetime, refresh-token prohibition, App ownership, gateway protocol, remote-control protocol, or non-CI behavior.

## Open-source-first startup gate

This is a repository-specific protected-device allowlist mismatch, not a missing generic implementation. No external dependency or protocol can safely replace the existing validator. The repair reuses the already-implemented exact-suffix pattern established for `-macos-app` and the existing Rust/Node contract tests; no upstream code and no new dependency are introduced.

## Acceptance

- PR-head GitHub Actions prove Rust and Node security/contract checks pass.
- Protected merge only; no branch protection bypass.
- Read back the resulting canonical main.
- The resulting current-main delivery chain must build/package from that exact SHA, publish a same-SHA Release, and run a new Windows interactive job.
- The new installed App must reach `controllable device online` with a fresh `gha-<run>-<attempt>-windows-app` identity before external semantic control.
- Full final acceptance still requires current-canonical-SHA Windows/macOS visual/trace/report/log artifacts plus stable Global Dharma journey evidence; this validator fix alone is not completion.
