# Source of truth

Project identity is immutable: FAB-P0011 / CWA, registered in projects/PORTFOLIO.json;
the allocation baseline recorded there is canonical main
`656d05e8d66bfed241f5b9d871a062abfbf2f952`.
The canonical implementation source is bhrumom/fabushi on main, under
projects/fabushi-chrome-web-app/ and the paths named by CWA-006.

The original user requirement is preserved in source/2026-09-12-user-requirement.md.
The prior implementation branch codex/fabushi-chrome-userscripts is an input and
comparison source, not canonical state; only compatible modules are adapted.
Open-source references are the official Chrome Native Messaging and Debugger API
documentation and the GoogleChrome samples listed in source/README.md.

Precedence is: latest user requirement persisted here; canonical portfolio registry and
identity policy; this file and source intake; accepted ADRs/specs; management state; live
GitHub code/PR/CI/release/deployment facts; external mirrors; chat memory. If records
disagree, preserve the historical record, verify live facts, and append a correction.
A task is not complete while protected merge, post-main package/E2E evidence, release or
migration gates remain open.

## 2026-09-23 Grok Bot extension parity amendment

The latest product requirement is governed by
`docs/08-grok-bot-0.18-extension-architecture-product-parity.md`.
Fabushi Chrome is now required to become the Chrome-extension edition of Grok Bot 0.18
under Fabushi identity while preserving all approved CWA browser-control, userscript,
Mini Apps, Marketplace, account, same-account MCP and Native Messaging capabilities.

The migration rule is per-source-file audit/disposition plus per-product-responsibility
Chrome implementation; equal source/target file counts are not required. The final product
must expose the Grok Agent UI and lifecycle through the canonical extension app, with MV3
Service Worker limited to transport/capability brokering and with durable run truth owned
by Coordinator/Host. Desktop Native Messaging is an optional local capability transport,
not a prerequisite for core Agent use.
