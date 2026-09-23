# CWA-013 — Grok Bot 0.18 Chrome Extension Parity

Status: in-progress / Spec active  
Project: FAB-P0011 / CWA  
Owner: Fabushi browser-platform maintainers  
Created: 2026-09-23

## Goal

Rebuild Fabushi Chrome as the Chrome-extension edition of Grok Bot 0.18 while preserving every approved existing Fabushi extension capability.

Canonical Spec:

`projects/fabushi-chrome-web-app/docs/08-grok-bot-0.18-extension-architecture-product-parity.md`

Reference baseline:

`b-nnett/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`

## Mandatory principles

1. Per-source-file audit/disposition; no silent Grok source/frontend omission.
2. Per-product-responsibility Chrome implementation; no one-to-one target file-count requirement.
3. Full-page Grok-shaped Agent UI is the canonical extension product surface.
4. Preserve Browser Control nine commands/eight actions, CDP/OOPIF/download/tab lifecycle.
5. Preserve Mini Apps, Marketplace and userscript install/update/enable/disable/recovery.
6. Preserve Fabushi browser login, same-account MCP, cross-account denial and logout revocation.
7. MV3 Service Worker is a thin broker; durable Agent/run truth belongs to Coordinator/Host.
8. Local Native Messaging and remote transport implement one logical Coordinator protocol.
9. Desktop connection is optional for core Agent use.
10. Exact-HEAD packaged acceptance must prove Grok Bot Chrome effect and existing-feature non-regression.

## Implementation sequence

- Generate strict Grok Chrome parity ledger.
- Build full-page React/TypeScript Grok renderer under Fabushi identity.
- Introduce typed Extension Platform Runtime.
- Introduce canonical Coordinator client and local/remote transport adapters.
- Route Agent lifecycle, transcript, tools, MCP, settings and context through Coordinator -> Host -> Runner.
- Expose Browser Control as privileged Runner/tool capability.
- Integrate Mini Apps/Marketplace/Userscripts/account status into Grok-shaped UI.
- Cut over toolbar action to full application surface; popup is optional auxiliary only.
- Remove old primary shell after capability cutover.
- Run exact-HEAD unit/contract/security/Chrome packaged E2E and release/Web Store gates.

## Required final evidence

- ledger strict report;
- exact source SHA;
- packaged extension version and ZIP SHA-256;
- full Grok UI screenshots/video;
- ordinary chat streaming trace;
- real browser-control tool trace;
- MCP trace;
- Service Worker restart same-run recovery trace;
- app reload/reopen same-run recovery trace;
- existing Browser Control regression;
- existing userscript regression;
- existing Mini Apps/Marketplace regression;
- existing account/same-account MCP regression;
- Chrome Web Store release evidence when release is in scope.

## Completion

CWA-013 is not complete while either condition is false:

- Grok Bot 0.18 Agent functions/UI/runtime effect are not fully proven; or
- any approved existing Fabushi Chrome capability regresses or disappears.
