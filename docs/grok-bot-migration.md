# Grok Bot 0.16.0 → Fabushi Electron / Mahayana migration

This document is the implementation ledger for the authorized migration from
`Grok_Bot_0.16.0.dmg`. It distinguishes source that is reused byte-for-byte
from source that must be adapted because it depends on Electron or private
`@anysphere/*` runtime packages.

## Recovered architecture

- Desktop shell: Electron (`dist/electron-main/main.cjs`).
- Renderer: React 19 + TypeScript, bundled by Vite.
- Styling: StyleX plus component CSS.
- Agent host: Node.js/TypeScript packages compiled to ESM/CJS.
- Protocols: Buf/Protobuf and Connect RPC.
- State: local agent KV/blob stores, transcripts, synchronized agent store and
  SQLite-backed search/state services.
- Rich results: Markdown/GFM, Highlight.js/Shiki, KaTeX, Mermaid, PDF.js,
  Mammoth and XLSX.
- Extensibility: MCP, connectors, skills, plugins, hooks, subagents and local
  tool execution.

Recovered source root:

`/Users/gloriachan/Downloads/Grok_Bot_0.16.0_extracted/recovered`

Renderer assets root:

`/Users/gloriachan/Downloads/Grok_Bot_0.16.0_extracted/app/dist/renderer/assets`

Recovery audit (2026-08-16):

- 13 source maps were present in the packaged application.
- 7,866 source entries were inventoried; 7,787 include `sourcesContent`.
- 1,861 first-party Grok Bot files (28,113,052 bytes) are recoverable exactly from
  those source maps.
- The renderer bundle itself does not ship renderer source maps. Its original TSX
  therefore cannot be recovered byte-for-byte; the renderer reference remains the
  complete 6.2 MB Vite JS bundle, 544 KB CSS bundle and packaged assets.
- Exact recovered source hashes and the Electron migration inventory live in
  `contracts/automation/grok-bot-electron-migration.json`.

## Canonical Electron UI rule

The UI previously migrated into the Tauri host is **not reimplemented or copied
into a second Electron-only shell**. `desktop/src/main.tsx` directly renders the
same maintained `frontend/apps/web/src/app/host/host-client.tsx` used by the
Tauri host migration. This keeps the Tauri-era Grok UI, components, styles and
interaction code as one source of truth while Electron supplies the native IPC
transport.

The protected historical surface includes the Host workspace, workflow panel,
Bot marks, group chat, extension studio, rich transcript, the four direct Grok
agent utilities, six adapted recovered Grok modules, Host transport contracts
and the desktop remote-computer peer. The standalone Tauri/web entry wrappers
and mobile remote-control client remain preserved for compatibility, but they
are not allowed to replace the Electron runtime path.

`.github/scripts/assert-grok-bot-electron-migration.py` walks the Electron import
graph and fails CI if any protected Tauri/Grok module falls out of the Electron
bundle, if a byte-for-byte Grok utility drifts, if an adapted recovered module
loses a required original export, or if Electron stops taking priority over the
legacy Tauri bridge.

## Directly reused source

These modules are copied from the recovered source and imported by the current
Host UI:

- `frontend/apps/web/src/lib/grok-agent/token-estimate.js`
- `frontend/apps/web/src/lib/grok-agent/agent-mode-guidance.js`
- `frontend/apps/web/src/lib/grok-agent/formatting.js`
- `frontend/apps/web/src/lib/grok-agent/automation-schedule.js`

The renderer's lazy chunks cannot be treated as maintainable application source:
they import hashed symbols from the original 6.2 MB renderer runtime. Copying
those chunks alone would produce an opaque, tightly-coupled second application.
Their component states, labels, spacing, assets and behavior are used as the
reference while the shared React Host remains the maintainable Electron UI; the
standalone utilities above remain direct source reuse.

## Implemented migration surface

| Original surface | Fabushi / Mahayana implementation |
| --- | --- |
| Always-on agent chat | Real Mahayana Runtime/Codex conversation send, streaming and history |
| Agent / Ask / Plan | Shared protocol modes plus directly reused mode guidance |
| Model routing | Runtime model event, selector and model/status UI |
| Attachments | Text attachment context, limits and directly reused token estimate |
| Tool activity | Structured Codex plan, reasoning summary, shell, patch, MCP, subagent, web, image and compaction events |
| Usage | Actual provider token usage and context-window meter |
| Conversations | Runtime list, search, open and restore |
| Capability registry | Runtime Agent/Bot/MiniApp/Contact registry exposed through `capability.list` |
| Capability mentions | `@` suggestion menu backed by the Runtime registry |
| Agent network | Runtime-backed network overlay and empty state |
| Scheduled routines | Persistent Host CRUD, five-field cron, aliases, `@every`, enable/pause, manual run, next-run calculation and automatic wake-up |
| Plugins | Marketplace, install, open, isolated MiniApp iframe and MCP bridge |
| Approval cards | deny, allow once and Runtime `AcceptForSession` |
| Settings | General, appearance, notifications, local execution, egress, security key, auto-review rules, usage and updates |
| First-run UI | Three live-reference onboarding screens: task hand-off, Bot roles and daily tools |
| Signed-out UI | Original black welcome composition and two-stage login flow |
| Authentication | Google, Apple, Microsoft, GitHub and password session transport |
| Desktop workspace | Live-reference two-pane chat, collapsible Computer/Routines detail pane, compact message bubbles and bottom composer |
| Responsive UI | Desktop, tablet and mobile layouts, including settings navigation |

## Source inventory still routed through Mahayana/Codex

The recovered implementation contains read/write/edit/delete, shell and
background shell, grep/glob/list, web search/fetch, image generation,
computer-use, code lineage, plan/question/todo/goals, conversation search,
MCP resources/tools, hooks, skills, subagents, Git/SCM, summarization,
compaction, memory synthesis and transcript persistence. These are not copied
as a second JavaScript agent runtime: the embedded Rust Codex runtime already
owns these capabilities and the Host projects their events into the UI. This
avoids two competing permission, session and tool-execution engines.

## Remaining runtime / visual parity audit

The source migration and historical Tauri UI preservation are guarded separately
from this list. The following items still require live signed-in reference states,
pixel/interaction validation, or additional product service contracts before
full Grok 0.16.0 behavioral parity can be marked complete:

- Event routine sources (Slack, Git, Teams, Linear, Sentry and PagerDuty) and
  their incoming event cards. Scheduled routines are implemented.
- Connector account setup, rename/remove, OAuth and tool lists.
- Skills marketplace/private/team publishing flows.
- Hidden Bots management.
- Email and Slack draft approval cards.
- Secret request and listener-connect cards.
- Rich Markdown/code/diff/PDF/XLSX/Mermaid result renderers.
- Update service wiring (the settings UI exists; updater service contract is
  not yet connected).
- Remaining signed-in state-by-state pixel comparison for overlays and rich
  result cards. The original authenticated workspace and first-run flow were
  inspected live on 2026-08-13.

Every item must be moved from this section into the implemented table only
after its real behavior and responsive UI are verified.
