# CWA-012 evidence index

## Source userscript release

- Repository: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`
- PR: [#32](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/32)
- Main/release SHA: `cb30da99bce3a02295863cfb9d74c592947e0a42`
- Release: [v2.9.39](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.39)
- Live source readback: `@version 2.9.39`, stable raw `@updateURL` and `@downloadURL`, asset size `237771` bytes.

## Independent Chrome distribution

- Repository: `bhrumom/fabushi-chrome-extension`
- PR: [#2](https://github.com/bhrumom/fabushi-chrome-extension/pull/2)
- Main/tag SHA: `dc24b66640a719b7742c84d30bb7c84483fd55e9`
- Release: [v0.6.14](https://github.com/bhrumom/fabushi-chrome-extension/releases/tag/v0.6.14)
- Release workflow: [35373881863](https://github.com/bhrumom/fabushi-chrome-extension/actions/runs/35373881863)
- Asset: `fabushi-chrome-0.6.14.zip` (129502 bytes), produced by the tag workflow.

## Local Chrome readback

- Extension ID: `gdoggbammnghfbdcmlngjcbffblbllod`
- Installed path: `/Users/gloriachan/Downloads/fabushi-0.3.0`
- Chrome extension details page after reload: `Fabushi 0.6.14`.
- Marketplace card readback: `ChatGPT 自动确认` shows `2.9.39`; status shows `已安装 2.9.39 · GitHub 发布物一致`.
- Bundled userscript: `2.9.39` with stable raw update/download URLs.
- Pre-update backup: `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.6.13-20260919.W8qBcY/extension`.

## Remaining governed gate

The independent distribution release and local profile update are verified. The canonical
`bhrumom/fabushi` host PR and exact-main package are now recorded below; the required
interactive packaged journey screenshot/video/trace/report bundle and Web Store review remain
open before CWA-012 can be marked passed.

## Canonical Fabushi main delivery

- Implementation PR [#2713](https://github.com/bhrumom/fabushi/pull/2713), packager fix [#2714](https://github.com/bhrumom/fabushi/pull/2714), and workflow gate fix [#2715](https://github.com/bhrumom/fabushi/pull/2715) merged through the queue; canonical SHA: `42b8bacf6f41718da342f3c3c71114045a18ea68`.
- Exact-source package: [35349390987](https://github.com/bhrumom/fabushi/actions/runs/35349390987), passed for `0.6.13`; post-package trigger: [35349418461](https://github.com/bhrumom/fabushi/actions/runs/35349418461), passed.
- Web Store publish attempt: [35349440443](https://github.com/bhrumom/fabushi/actions/runs/35349440443), failed closed with HTTP 400 `NOT_UPDATEABLE` because the existing item is in review.

The local profile update is verified; the remaining blocker is external Web Store review plus the required interactive packaged evidence gate.

## Canonical Fabushi main delivery — version display follow-up

- Version-display PR [#2719](https://github.com/bhrumom/fabushi/pull/2719) merged through Merge Queue at canonical `main@aa1549894834ba4ba6d855d8ddee7252f58dddc7`.
- Project portfolio governance: [35374551665](https://github.com/bhrumom/fabushi/actions/runs/35374551665), passed.
- Exact-source Chrome package: [35374551750](https://github.com/bhrumom/fabushi/actions/runs/35374551750), passed; version `0.6.14`; artifact `10559816801`; artifact digest `sha256:620c70831b10219f052d3f4eb08fb3ccba99a023e9094972d64d1e25227752aa`; package archive SHA-256 `94691e90cd734a7680bff2d030f1f04fefdabfc5a4d27a15038e0c53b0e4f955`.
- Post-package publication trigger: [35374588345](https://github.com/bhrumom/fabushi/actions/runs/35374588345), passed.
- Automatic Web Store submission: [35374612292](https://github.com/bhrumom/fabushi/actions/runs/35374612292), failed closed with HTTP 400 `NOT_UPDATEABLE` because the existing item remains in review; package provenance and checksums passed before the external API rejection.
