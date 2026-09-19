# 2026-09-19 — 本地 Chrome 插件更新到 v0.6.15

## 用户要求

对应的 Fabushi Chrome 插件发布新版本后，将本机未打包扩展更新到线上最新 Release，并在 Chrome 中重新加载、核对扩展和内置自动确认脚本版本。

## Verified release

- Independent repository: `bhrumom/fabushi-chrome-extension`
- Release: [v0.6.15](https://github.com/bhrumom/fabushi-chrome-extension/releases/tag/v0.6.15)
- Tag/source commit: `9a209c41bcd06b58994ad257bb306a06daa81c43`
- Asset: `fabushi-chrome-0.6.15.zip`, 132536 bytes
- Asset SHA-256: `c07e83d1e3eec537ec088b606ef967f931ce90fd522eaaa09b2d4908d368be1`

The bundled source userscript is `v2.9.41`, from
[the userscript Release](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.41), with the stable raw `@updateURL` and `@downloadURL`.

## Local readback

- Extension path: `/Users/gloriachan/Downloads/fabushi-0.3.0`
- Extension ID: `gdoggbammnghfbdcmlngjcbffblbllod`
- Chrome extensions page after reload: `Fabushi 0.6.15`
- Marketplace after manual check: `ChatGPT 自动确认 2.9.41`; `已安装 2.9.41 · GitHub 发布物一致`
- Previous local directory backup: `/Users/gloriachan/Downloads/fabushi-0.3.0.backup-0.6.14-20260919.bYzVtk/extension`

No application build or local E2E was run; this was a release-asset replacement and Chrome UI reload/readback.
