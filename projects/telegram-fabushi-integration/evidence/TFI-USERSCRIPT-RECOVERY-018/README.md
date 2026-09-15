# TFI-USERSCRIPT-RECOVERY-018 evidence index

本索引绑定 `FAB-P0001` / `TFI-USERSCRIPT-RECOVERY-018`。所有最终证据必须指向精确 canonical `main` SHA、Chrome 版本、Actions run/job、旅程标识和时间。

## Source

- source PR #24: <https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/24>
- source main: `5f7d1f26a9883e6806ec855f5f2177ad737aa07e`
- source Release: <https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.31>
- asset: `chatgpt-auto-confirm.user.js`, 225544 bytes, SHA-256 `1e025a9b64bcba225059a0768fb08b5bcf818f902f8c7c4e5980505958e6fe2a`
- source Actions: PR #24 run `34931882570`, success; source lightweight regression `121/121` passed, plus `node --check` and `git diff --check`.

## Parent delivery

- parent PR: pending
- canonical main: pending
- Chrome package/version: `0.6.9`, exact-main run/artifact pending
- required evidence bundle: labelled screenshots, complete journey video, Playwright trace/HTML report, journey/native logs, content manifest/checksums; upload on pass and failure paths.

## Root-cause contract

The navigation host must receive canonical plugin identity, a grant must not count as a committed route, and stale grants must be cancellable without adding a cooldown. Focused host/source regression files cover these invariants.
