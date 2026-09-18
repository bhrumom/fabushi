# CWA-012 evidence index

## Source userscript release

- Repository: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`
- PR: [#32](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/32)
- Main SHA: `d07fd543096662f7a02d45bfb09cd6aa7c28e6ed`
- Release: [v2.9.38](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.38)
- CI: [35342032659](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/35342032659)
- Live source readback: `@version 2.9.38`, stable raw `@updateURL` and `@downloadURL`.

## Independent Chrome distribution

- Repository: `bhrumom/fabushi-chrome-extension`
- PR: [#1](https://github.com/bhrumom/fabushi-chrome-extension/pull/1)
- Main/tag SHA: `5a83c837f8fff27cc57c0f2fc9e0db5d13ce9665`
- Release: [v0.6.13](https://github.com/bhrumom/fabushi-chrome-extension/releases/tag/v0.6.13)
- Release workflow: [35346479236](https://github.com/bhrumom/fabushi-chrome-extension/actions/runs/35346479236)
- Asset: `fabushi-chrome-0.6.13.zip` (129954 bytes), produced by the tag workflow.

## Local Chrome readback

- Extension ID: `gdoggbammnghfbdcmlngjcbffblbllod`
- Installed path: `/Users/gloriachan/Downloads/fabushi-0.3.0`
- Chrome extension details page after reload: `Fabushi 0.6.13`.
- Bundled userscript: `2.9.38` with stable raw update/download URLs.
- Pre-update backup: `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.6.9-20260918-204801`.

## Remaining governed gate

The independent distribution release and local profile update are verified. The canonical
`bhrumom/fabushi` host PR, exact-main packaged journey, and required screenshot/video/trace/report
bundle remain open; this index must be extended with those links before CWA-012 is marked passed.

## Canonical Fabushi main delivery\n\n- Implementation PR [#2713](https://github.com/bhrumom/fabushi/pull/2713), packager fix [#2714](https://github.com/bhrumom/fabushi/pull/2714), and workflow gate fix [#2715](https://github.com/bhrumom/fabushi/pull/2715) merged through the queue; canonical SHA: `42b8bacf6f41718da342f3c3c71114045a18ea68`.\n- Exact-source package: [35349390987](https://github.com/bhrumom/fabushi/actions/runs/35349390987), passed for `0.6.13`; post-package trigger: [35349418461](https://github.com/bhrumom/fabushi/actions/runs/35349418461), passed.\n- Web Store publish attempt: [35349440443](https://github.com/bhrumom/fabushi/actions/runs/35349440443), failed closed with HTTP 400 `NOT_UPDATEABLE` because the existing item is in review.\n\nThe local profile update is verified; the remaining blocker is external Web Store review plus the required interactive packaged evidence gate.