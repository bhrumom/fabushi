# TFI-USERSCRIPT-RECOVERY-013 evidence index

Project: `FAB-P0001` / `TFI`. Updated: 2026-09-14 (Asia/Shanghai).

## Source userscript release

- Canonical source main: `faf68931dfa5c915feb316ea2a8da1de45384b96`.
- Source Test: [GitHub Actions 34813245918](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/34813245918) — success.
- Release: [v2.9.23](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.23), release id `388200671`.
- Asset: `chatgpt-auto-confirm.user.js`, id `562815404`, 204587 bytes, SHA-256 `80bea8ea03d18bd258bd4a326d150786b01cb52d2a731db7a04c7d4ffcaee7e4`.

## Host exact-main packaged evidence

- Canonical Fabushi main: `13188628da46b88db843c9c5b4d59100233e3a21`.
- Chrome post-main workflow: [34817384069](https://github.com/bhrumom/fabushi/actions/runs/34817384069) — success.
- Evidence artifact: `10337146244`, SHA-256 `a3fd9f277e5430c02c8c83b2b36c61e0d783221eefc16ee63bba9221ecd53e3c`, retention until 2026-12-13.
- The artifact includes `01-startup-fixture.png`, `02-fabushi-shell.png`, `03-browser-view.png`, `05-after-browser-control.png`, `06-cdp-screenshot.png`, two page video segments, `playwright-report.html`, `trace.zip` and `native-journey.json`.

## Official MCP remote Runner gate

- Service health: [https://fabushi-mcp.ombhrum.com/health](https://fabushi-mcp.ombhrum.com/health) returned HTTP 200 during this round.
- `fabushi test` connector account call returned `Mcp error: -32603: Internal error`; no account identity, device id or credential was inferred.
- Remote Runner manual journey is not executed yet. Required order after connector recovery: list devices → describe selected tools → `ci_session_status` → perform memory/continuity actions → `ci_session_note` → `ci_session_finish`.
- Pending evidence: same-account login/device discovery and exact-SHA screenshots, complete video, trace/report, and session note/finish.
