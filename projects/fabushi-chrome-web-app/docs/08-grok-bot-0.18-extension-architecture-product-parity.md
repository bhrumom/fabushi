# Grok Bot 0.18 → Fabushi Chrome Extension Architecture, Product & UI Parity — Specification

Status: active  
Owner: Fabushi Chrome / Browser Platform  
Last updated: 2026-09-23  
Project: FAB-P0011 / CWA  
Related task/PR: CWA-013; Grok Bot 0.18 extension parity  
Target repository: `bhrumom/fabushi`  
Target baseline when authored: `f1033a095bba7cf909fa212a6e8b7f2a099ae821`  
Reference repository: `b-nnett/grok-bot-0.18-reconstructed`  
Reference baseline: `a9f633e09d49a85829b8236331b9e21f7e612634`

## 1. Context / problem

Fabushi already ships a first-class Chrome MV3 extension with product UI and substantial browser-native functionality. At the target baseline the active package under `chatgpt-vps-control/chrome-platform/extension/**` includes:

- Fabushi Chats;
- Mini Apps;
- Marketplace;
- Settings;
- browser-control bridge;
- Chrome Debugger/CDP and OOPIF handling;
- downloads and tab ownership/generation semantics;
- Native Messaging integration;
- Fabushi account login;
- same-account official MCP registration;
- userscript import/install/update/enable/disable;
- bundled ChatGPT automation userscript;
- userscript recovery/watchdog behavior;
- optional desktop enhancement through `com.fabushi.chrome_platform`.

Those capabilities are product requirements and must be retained.

However, the extension is not yet the Chrome-extension edition of Grok Bot 0.18. Its current `app.html/app.js` shell is a Fabushi-specific navigation application rather than the complete Grok Agent workspace, and its renderer/transport/runtime responsibilities are not yet mapped exhaustively to the Grok Bot frontend, coordinator, Host, Runner, MCP, recovery, and UI behavior model.

The target is therefore **not** to replace the current extension with Grok code and **not** to remove Fabushi-specific browser capabilities. The target is:

> **Grok Bot 0.18 product architecture, Agent behavior, and UI experience in Chrome-extension form, plus all existing Fabushi extension capabilities as approved extension-native capabilities.**

The Chrome extension must feel like a real Grok Bot client adapted to Chrome, not like a small browser-control utility that happens to have a chat page.

## 2. Canonical migration principle

The migration rule is:

> **per-source-file audit/disposition + per-product-responsibility Chrome implementation + zero regression of approved existing extension capabilities.**

Every pinned Grok `source/**` and `frontend/**` file must be accounted for in the parity ledger, but Fabushi Chrome does **not** need one physical target file for every Grok source file.

Allowed mappings include:

- one Grok file -> one extension implementation module;
- one Grok file -> multiple extension/native/server modules;
- multiple Grok files -> one extension implementation module when no Grok architectural boundary/responsibility is collapsed;
- Grok source mechanism -> reviewed Chrome-adapted implementation;
- Grok source mechanism -> reviewed `not-applicable` only when the mechanism is intrinsically desktop-only and the still-required user effect has an explicit replacement behavior.

Creating empty/no-op mirror files only to match source-file counts is incorrect.

## 3. Goal

Build Fabushi Chrome as the Chrome-extension edition of Grok Bot 0.18 with these properties:

1. The primary extension application UI reproduces Grok Bot's Agent workspace, interaction model, information hierarchy, state presentation, and visual language under Fabushi branding.
2. Core Agent behavior is equivalent: durable turns, streaming, thinking/running/tool states, cancellation, retry/recovery, transcript resync, MCP/connectors, settings, attachments/media where Chrome allows them, and remote-computer/browser-control surfaces.
3. Grok's major runtime ownership boundaries remain explicit: Renderer -> Extension Platform Runtime -> Coordinator -> Host -> Runner.
4. MV3 Service Worker is a transport/capability broker, not a second Host, transcript owner, or Agent runtime.
5. Existing Fabushi extension functions remain first-class, tested, and visible in the Grok-shaped product.
6. Desktop Native Messaging is an optional local transport/capability adapter, not a requirement for the extension's core Agent UI to function.
7. When desktop/local runtime is unavailable, an authenticated remote Coordinator/Host path provides the same Agent protocol and product semantics.
8. The extension uses the most appropriate language/runtime for each responsibility.
9. Final acceptance is based on **Grok Bot Chrome effect**, not file presence or screenshots alone.

## 4. Non-goals

- Do not embed Electron inside Chrome.
- Do not copy the Grok packaged renderer or binary-derived proprietary assets into the extension.
- Do not mechanically generate one extension file per Grok file.
- Do not remove current browser-control, userscript, Marketplace, Mini Apps, login, or same-account MCP features merely because Grok does not contain identical extension modules.
- Do not keep the current Fabushi Chrome UI as a second parallel primary shell after Grok UI cutover.
- Do not implement the full Grok UI inside a tiny toolbar popup.
- Do not let the MV3 Service Worker own durable run truth, inference state, transcript truth, retry policy, or provider lifecycle.
- Do not expose long-lived credentials to extension renderer JavaScript.
- Do not weaken current generation/tab ownership/security checks to simplify Grok parity.
- Do not use `not-applicable` to silently remove a product capability that has a legitimate Chrome-native or remote implementation.

## 5. Existing Fabushi capabilities that must be preserved

These are approved Chrome-specific extensions to the Grok-shaped product and are not "extra code to remove":

### CWA-EX-001 — Browser control bridge

Preserve the complete existing Browser Control contract, including:

- the legacy nine commands;
- the legacy eight actions;
- tab listing/selection;
- title/URL/generation-bound claims;
- stale claim rejection;
- Chrome Debugger/CDP serialization;
- OOPIF handling;
- download handling;
- tab lifecycle and ownership;
- retain/release semantics;
- user tabs never being closed by automation unless an explicit product action authorizes it;
- fail-closed handling for unsupported/non-HTTP(S) pages.

### CWA-EX-002 — Userscript runtime

Preserve:

- bundled userscripts;
- import of local userscripts;
- Marketplace userscript installation;
- enable/disable/uninstall;
- approved update URL behavior;
- Chrome `userScripts`/`scripting` execution;
- page handshake;
- recovery capability lease/watchdog;
- current ChatGPT automation behavior and safety boundaries.

### CWA-EX-003 — Mini Apps and Marketplace

Preserve current Mini App and Marketplace functionality, installation/update projection, package provenance validation, and current user journeys.

### CWA-EX-004 — Fabushi account and same-account MCP

Preserve:

- independent Fabushi browser login;
- no refresh token in normal extension storage;
- account-scoped official MCP browser registration;
- cross-account denial;
- logout/revocation;
- session expiry/reconnect;
- stable extension-origin enforcement.

### CWA-EX-005 — Optional desktop/native enhancement

Preserve Native Messaging integration for local capabilities and desktop account/runtime enhancement, but it must become an adapter to the canonical Coordinator/Host model rather than a separate product runtime.

## 6. Grok Bot UI parity

### 6.1 Primary entry surface

The toolbar action must open the **full extension application surface**.

The full Grok-shaped workspace must not be constrained to the browser action popup. A compact popup may exist as an auxiliary launcher/status/control surface, but the canonical Agent UI is a full extension page/tab/window based on `app.html` or its successor.

The final product must not have two different primary application shells.

### 6.2 Required Grok-shaped product surfaces

At minimum the extension must implement and visually align:

- Agent/bot roster;
- conversation list;
- active conversation workspace;
- transcript;
- composer;
- rich input and attachment affordance where permitted;
- thinking/running/tool-running/streaming/waiting-user/completed/failed/recovered states;
- tool execution cards/status;
- stop/cancel;
- retry/recovery;
- reactions where supported by the reference;
- command/search affordances;
- Plugins/MCP/connectors;
- account/session surfaces;
- settings;
- remote-computer/browser-control context surface;
- Agent create/edit/delete/identity/avatar flows where present;
- deep-link/navigation behavior adapted to extension URLs;
- error and reconnect states;
- update/version state;
- help/about/feedback where part of the accepted reference.

### 6.3 Existing extension surfaces inside Grok UI

Existing Fabushi-specific areas must be integrated into the Grok-shaped information architecture instead of remaining as a competing shell:

- Browser Control;
- Mini Apps;
- Marketplace;
- Userscripts;
- Fabushi browser account status;
- desktop/local-runtime connection status.

They may appear as Grok-style sidebar destinations, context panels, settings/plugin surfaces, or tools, but they must retain their complete existing functionality.

### 6.4 Observable reference is normative for UI

The reconstructed Grok repository is incomplete for original frontend source. Therefore:

- readable reconstructed frontend source is an architecture/behavior reference;
- approved screenshots/video of the exact Grok 0.18 reference are normative for user-visible interaction when source and observable product differ;
- Fabushi branding replaces Grok branding;
- browser-extension-specific navigation/capability differences must be documented;
- proprietary or binary-derived assets are not copied without rights clearance.

## 7. Target architecture

```text
Full-page Chrome Extension Renderer
            |
            v
Extension Platform Runtime / typed bridge
            |
            v
MV3 Service Worker
  - transport broker
  - Chrome capability broker
  - lifecycle/reconnect broker
            |
     +------+------------------+
     |                         |
     v                         v
Local transport           Remote transport
Native Messaging          HTTPS/WebSocket
     |                         |
     +-----------+-------------+
                 v
       Mahayana Coordinator
                 |
                 v
               Host
                 |
          +------+------+
          |             |
          v             v
    Agent/Tool/MCP   Runner/Computer
                         |
                   browser-control
                   / local / remote
```

The renderer must never call Host or Runner implementation directly.

The Service Worker must never become the durable owner of turns, transcript, retries, provider execution, or Agent identity.

## 8. Grok source-area mapping

Default responsibility mapping:

| Grok Bot 0.18 | Fabushi Chrome responsibility |
| --- | --- |
| `frontend/**` | full-page extension renderer / React+TypeScript UI |
| `source/electron-preload/**` | extension platform runtime / typed bridge |
| `source/electron-main/**` | Chrome platform adapter, authenticated transport, settings/auth/plugin/attachment browser adapters |
| `source/node-agent-coordinator/**` | Mahayana Coordinator reached through local Native Messaging or remote transport |
| `source/host/**` | Mahayana Host / server or local host implementation |
| `source/local-exec-daemon/**` | local/native/browser capability adapters where allowed |
| `source/box-exec-daemon/**` | remote Runner/box capabilities |
| `source/shared/**` | shared wire contracts/schemas used by extension and runtime |
| `source/packages/**` | extension/runtime packages by responsibility |
| `source/internal/**` | internal runtime support or reviewed disposition |

This table defines ownership, not one-to-one filenames.

## 9. File-level parity ledger

Create and maintain a machine-readable ledger covering every pinned Grok `source/**` and `frontend/**` file.

Recommended canonical path:

`projects/fabushi-chrome-web-app/manifests/grok-bot-0.18-chrome-parity-ledger.json`

Minimum fields:

- `reference_path`
- `reference_blob_sha`
- `reference_responsibility`
- `reference_ui_effect`
- `chrome_effect`
- `platform_delta`
- `target_paths`
- `target_language`
- `runtime_owner`
- `transport`
- `parity_class`
- `status`
- `replacement_behavior`
- `tests`
- `production_evidence`
- `preserves_existing_cwa_capability`
- `notes`

Allowed lifecycle statuses may include `mapped`, `implementing`, `implemented`, `verified`, `blocked`.

Final acceptance requires every row to be `verified` or reviewed `not-applicable`.

A reviewed `not-applicable` record must explain:

1. the exact source mechanism/responsibility;
2. why Chrome cannot or should not implement that mechanism;
3. whether the user-facing effect still matters;
4. the Chrome-native or remote replacement when it does;
5. test/evidence proving no required product behavior silently disappeared.

## 10. Runtime / transport requirements

### EXT-RUN-001 — One Coordinator protocol

Local Native Messaging and remote HTTPS/WebSocket transports must carry the same logical Coordinator protocol and lifecycle semantics.

The UI must not have separate "desktop chat" and "remote chat" state machines.

### EXT-RUN-002 — Durable turn lifecycle

A turn must support, as applicable:

- accepted;
- queued;
- preparing;
- thinking;
- tool-running;
- streaming;
- waiting-user;
- completed;
- failed;
- cancelled;
- recovering.

### EXT-RUN-003 — Request/reply/event/streaming

Preserve typed lifecycle/request/reply/event semantics with:

- request IDs;
- turn/run IDs;
- generation/session fencing;
- streaming deltas;
- tool started/completed;
- cancellation;
- reconnect;
- resync;
- stale generation rejection;
- duplicate/out-of-order handling;
- bounded queues;
- deterministic disconnect settlement.

### EXT-RUN-004 — Service Worker suspension

Because Chrome may suspend/restart the MV3 Service Worker:

- no durable product truth may exist only in Service Worker memory;
- reconnection must rebuild transport state;
- the renderer can reattach after worker restart;
- pending turns must resync from Coordinator/Host truth;
- no duplicate send/tool execution may result from worker restart.

### EXT-RUN-005 — Renderer reload/reopen

Closing/reopening `app.html`, reloading it, or opening it in another extension tab must not lose a durable Agent run.

Multi-view ownership and event fanout must be explicit.

### EXT-RUN-006 — Desktop optionality

The full Agent product must remain functional when the desktop Native Messaging host is unavailable.

Desktop/local connection may add local-computer capabilities, local secrets, or local acceleration, but lack of desktop connection may not turn the extension into a static shell.

## 11. Host / Runner / browser-control integration

### EXT-HOST-001

Grok Host responsibilities remain behind Coordinator ownership. Extension UI does not directly own inference routing, provider retries, transcript mutation, MCP lifecycle, or tool orchestration.

### EXT-HOST-002

Existing `browser-control.js` becomes a privileged Chrome Runner/capability adapter reachable through typed Host/Coordinator tool contracts.

The existing generation-bound tab safety rules remain normative.

### EXT-HOST-003

Browser Control tool execution must project into the Grok-shaped transcript/tool UI:

```text
ToolStarted
 -> browser capability/claim
 -> CDP/tab/download action
 -> progress/result/error
 -> ToolCompleted
 -> Host continues inference
```

### EXT-HOST-004

Userscript capabilities remain a separate extension subsystem and must not receive unrestricted Agent/runtime credentials.

Agent-initiated userscript actions require explicit typed capability contracts.

## 12. Language and technology selection

Use the best-fit implementation per boundary.

| Boundary | Preferred implementation |
| --- | --- |
| Extension renderer | React + TypeScript |
| UI state projection | TypeScript |
| Extension platform runtime | TypeScript |
| MV3 Service Worker | TypeScript/JavaScript compiled for MV3 |
| Chrome APIs / Debugger / tabs / downloads / userScripts | TypeScript/JavaScript |
| Native Messaging protocol adapter | TypeScript/Node or Rust according to existing host/runtime fit |
| Mahayana Coordinator | Rust preferred |
| Host / durable Agent runtime | Rust preferred; ecosystem-specific adapters may use TypeScript |
| Runner / privileged native execution | Rust preferred |
| Userscripts | JavaScript userscript format |
| Shared wire schemas | language-neutral schema + generated Rust/TypeScript where practical |
| E2E | TypeScript / Playwright + real Chrome extension profile |

"Implemented in Rust" or "implemented in TypeScript" is never parity evidence by itself.

## 13. Security requirements

Existing security guarantees remain mandatory:

- Native Messaging host allowlists;
- stable release extension ID/origin checks;
- per-user secret isolation;
- no long-lived account credential in renderer;
- no refresh token in normal extension storage;
- `storage.session` for bounded browser account session state where appropriate;
- cross-account MCP denial;
- logout revokes browser registration;
- generation/title/URL claim fencing;
- capability-scoped browser actions;
- no arbitrary remote executable code loading;
- userscript source/provenance checks;
- secrets scrubbed from logs/evidence;
- CSP compatible with MV3 and no unsafe-eval requirement;
- remote Coordinator WebSocket must authenticate the Fabushi session and extension client;
- service-worker messages validate sender/origin/capability.

Grok parity may not weaken current extension security.

## 14. Failure / recovery matrix

Required tests include:

- desktop Native Messaging absent at startup;
- desktop Native Messaging disconnect/reconnect mid-turn;
- remote Coordinator disconnect/reconnect mid-turn;
- MV3 Service Worker restart mid-turn;
- full extension app reload mid-turn;
- app page closed then reopened mid-turn;
- duplicate extension app tabs;
- stale generation;
- duplicate request/reply/event;
- Host crash/recovery;
- Runner/browser-control error;
- tab closes during tool action;
- CDP detach;
- OOPIF changes;
- download cancellation/failure;
- userscript runner restart;
- browser login expiry;
- cross-account attempt;
- OAuth/MCP auth failure;
- extension update while a durable run is active;
- Chrome restart and restoration where product state is durable;
- incompatible protocol version.

Every case must settle deterministically or recover to the same durable run when that run still exists.

## 15. Grok Bot Chrome effect

A representative end-to-end task must show:

```text
User sends task in full Grok-shaped extension UI
  -> accepted
  -> preparing/thinking
  -> Host inference
  -> tool/MCP/Browser Runner requested
  -> ToolStarted visible in transcript/context
  -> real Chrome action executes
  -> ToolCompleted visible
  -> Host continues
  -> TranscriptDelta streams
  -> completed/failed
```

During that run, restart the Service Worker or reload/close/reopen the extension app:

```text
extension renderer/worker returns
  -> transport re-authenticates
  -> Coordinator resync
  -> same run ID/generation restored
  -> current tool/stream state restored
  -> no duplicate execution
  -> run continues/settles
```

This is a mandatory final acceptance flow.

## 16. Implementation strategy

### Phase 0 — Freeze / ledger

1. Pin Grok baseline.
2. Enumerate all Grok `source/**` + `frontend/**` files.
3. Record responsibilities/UI effects.
4. Map Chrome target path(s), runtime ownership, language, transport, and platform delta.
5. Mark existing Fabushi extension capability intersections.
6. Add strict ledger validation.

### Phase 1 — Full-page Grok renderer

Build the primary extension application as a Grok-shaped renderer under Fabushi identity.

The toolbar action opens this full application.

A popup, if retained, is auxiliary only.

### Phase 2 — Extension platform runtime

Create typed renderer contracts that replace ad-hoc direct `chrome.runtime.sendMessage` usage in product UI.

### Phase 3 — Coordinator transport

Implement one logical Coordinator client with:

- local Native Messaging adapter;
- remote HTTPS/WebSocket adapter;
- identical request/reply/event/streaming semantics.

### Phase 4 — Host/Runner product wiring

Wire conversation, streaming, tools, MCP, attachments, settings, remote computer, and browser-control through the Grok-shaped ownership chain.

### Phase 5 — Existing-capability integration

Integrate Browser, Mini Apps, Marketplace, Userscripts, account/MCP, and desktop status into Grok UI without reducing existing behavior.

### Phase 6 — Legacy shell cutover

Remove the old Fabushi-specific primary shell/navigation only after every retained capability has a production path in the new Grok UI.

No hidden fallback shell remains.

### Phase 7 — strict closure / package / Web Store

Run:

- parity ledger strict check;
- unit/contract/security;
- extension E2E;
- real browser-control journey;
- userscript regression;
- account/MCP regression;
- same-run recovery;
- exact-HEAD ZIP;
- Chrome Web Store package/review/release gates.

## 17. Verification

### Static / architecture

Fail if:

- any pinned Grok source/frontend file is unclassified;
- any product-relevant Grok responsibility lacks a target implementation/equivalent;
- any current required CWA capability disappears;
- Service Worker becomes canonical Agent/Host truth;
- renderer bypasses Coordinator to Host/Runner;
- old primary shell remains a normal production fallback;
- strict checker requires equal target/source file counts;
- unapproved runtime remote code is loaded.

### Contract tests

Cover:

- Coordinator lifecycle/request/reply/event;
- streaming;
- cancel;
- reconnect/resync;
- Service Worker restart;
- local/remote transport equivalence;
- Browser Control nine commands/eight actions;
- generation-bound claims;
- MCP auth/account/tool lifecycle;
- userscript lifecycle;
- package/Marketplace install/update.

### Chrome packaged E2E

Use a real unpacked/packaged extension in Chrome.

Required journeys:

1. toolbar action -> full Grok-shaped app;
2. login;
3. open/create Agent;
4. open/create conversation;
5. send ordinary chat;
6. send tool/browser task;
7. thinking/tool-running/streaming/completed states;
8. stop/cancel;
9. Service Worker restart and same-run resync;
10. app reload/reopen and same-run resync;
11. Browser Control;
12. OOPIF;
13. download;
14. Mini Apps;
15. Marketplace;
16. userscript install/enable/disable/update/recovery;
17. same-account MCP;
18. cross-account denial;
19. desktop disconnect while remote path remains usable;
20. settings;
21. extension update/reload;
22. logout/revocation.

## 18. Acceptance criteria / Definition of Done

- **AC-EXT-01**: Grok reference baseline is pinned.
- **AC-EXT-02**: 100% of pinned Grok `source/**` + `frontend/**` files are represented exactly once in the Chrome parity ledger.
- **AC-EXT-03**: Every product-relevant Grok responsibility has a real Chrome production implementation or evidenced equivalent; no one-to-one target file count is required.
- **AC-EXT-04**: Full-page extension UI reproduces the approved Grok Bot Agent workspace/function/UI under Fabushi branding.
- **AC-EXT-05**: Toolbar action opens the full app; popup is absent or auxiliary only.
- **AC-EXT-06**: Renderer -> Platform Runtime -> Coordinator -> Host -> Runner ownership is real and production-wired.
- **AC-EXT-07**: Service Worker is a thin broker and survives restart without becoming product truth.
- **AC-EXT-08**: Core Agent use works without desktop Native Messaging by using the remote Coordinator path.
- **AC-EXT-09**: Local Native Messaging and remote Coordinator transports have equivalent Agent protocol behavior.
- **AC-EXT-10**: Existing Browser Control nine-command/eight-action/CDP/OOPIF/download/tab lifecycle behavior has zero regression.
- **AC-EXT-11**: Existing userscript installation/update/enable/disable/recovery behavior has zero regression.
- **AC-EXT-12**: Existing Mini Apps and Marketplace behavior has zero regression.
- **AC-EXT-13**: Existing Fabushi browser login and same-account MCP behavior has zero regression.
- **AC-EXT-14**: Grok Plugins/MCP/connectors product UI and lifecycle are implemented.
- **AC-EXT-15**: Grok conversation/transcript/composer/streaming/tool/recovery UI and behavior are implemented.
- **AC-EXT-16**: Grok remote-computer/context role is represented through Chrome Browser Control/local/remote Runner surfaces as appropriate.
- **AC-EXT-17**: Extension app/worker reload during a durable run resyncs the same run without silent loss or duplicate tool execution.
- **AC-EXT-18**: No old Fabushi Chrome primary shell remains as a hidden production fallback.
- **AC-EXT-19**: Security guarantees are not weakened by Grok parity.
- **AC-EXT-20**: Exact-HEAD packaged Chrome E2E passes all required Grok and existing-CWA journeys.
- **AC-EXT-21**: Exact-HEAD ZIP, content manifest, checksum, permission review, release metadata, and Chrome Web Store delivery evidence are recorded.
- **AC-EXT-22 — Grok Bot Chrome effect**: the packaged extension proves the full accepted -> thinking -> real tool/MCP/Browser Runner -> live tool result -> continued inference -> streaming -> terminal lifecycle, plus same-run recovery after Service Worker/app restart.
- **AC-EXT-23**: Final compliance review records every requirement/AC as passed, blocked, or not-applicable with evidence, with no mandatory blocked row for completion.

## 19. Release / migration / rollback

Migration is incremental but final product has one primary Grok-shaped extension shell.

Existing extension data must be preserved where compatible:

- userscript registrations/settings;
- Marketplace installed state;
- account/session metadata as allowed;
- Browser Control generation/session state where durable;
- user preferences.

Rollback occurs at extension package/version boundary. Do not ship two primary UIs/runtimes indefinitely as a rollback mechanism.

A release is blocked if:

- existing CWA functionality regresses;
- Grok Agent core is only mocked;
- desktop connection is still mandatory for basic Agent use;
- Service Worker owns durable run truth;
- same-run recovery fails;
- exact-HEAD package/E2E evidence is incomplete.

## 20. Observability / evidence

Evidence bundle includes:

- exact source SHA;
- extension version;
- ZIP SHA-256;
- content manifest;
- Grok parity ledger report;
- UI screenshots/video;
- full Agent turn trace;
- run ID / generation / request IDs;
- Service Worker restart/recovery trace;
- browser-control tool trace;
- MCP/account trace;
- userscript regression trace;
- Chrome version/profile;
- Native Messaging local path evidence;
- remote Coordinator path evidence;
- Web Store release/listing evidence when release is in scope.

## 21. References / provenance

Primary Grok reference:

- `b-nnett/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`

Fabushi Chrome current implementation:

- `chatgpt-vps-control/chrome-platform/extension/**`
- `chatgpt-vps-control/scripts/chrome-platform-host.mjs`
- `chatgpt-vps-control/scripts/browser-extension-host.mjs`
- `chatgpt-vps-control/lib/browser-extension-bridge.js`
- `desktop/electron/chrome-platform-server.cjs`
- `projects/fabushi-chrome-web-app/**`

The Grok repository is an unofficial reconstruction. Use it as architecture, protocol, behavior, and UI evidence. Do not assume permission to redistribute proprietary binary-derived assets or unlicensed source text.

## 22. Initial compliance record

| Requirement / AC | Status | Evidence / reason |
| --- | --- | --- |
| Existing CWA capabilities | passed-current-baseline | Current main contains Browser Control, userscript, Marketplace/Mini Apps, account and same-account MCP implementation; regression protection remains required. |
| AC-EXT-01 | passed | Grok baseline pinned by this Spec. |
| AC-EXT-02 | pending | Chrome parity ledger not yet generated. |
| AC-EXT-03 | pending | Product-responsibility closure not yet performed. |
| AC-EXT-04 | pending | Current app shell is not Grok Bot UI parity. |
| AC-EXT-05 | pending | Current manifest uses `action.default_popup = app.html`; full-page primary entry cutover is not complete. |
| AC-EXT-06 | pending | Current bridge does not yet prove complete Coordinator-shaped ownership. |
| AC-EXT-07 | pending | Service-worker restart parity not yet fully proven for Grok Agent lifecycle. |
| AC-EXT-08 | pending | Core Agent product without desktop Native Messaging not yet proven. |
| AC-EXT-09 | pending | Local/remote Coordinator transport equivalence not yet proven. |
| AC-EXT-10 | pending | Existing Browser Control must be regression-tested on the final architecture. |
| AC-EXT-11 | pending | Existing userscript functions must be regression-tested on the final architecture. |
| AC-EXT-12 | pending | Mini Apps/Marketplace must be regression-tested on the final architecture. |
| AC-EXT-13 | pending | Browser account/same-account MCP must be regression-tested on the final architecture. |
| AC-EXT-14 | pending | Grok Plugins/MCP UI parity not complete. |
| AC-EXT-15 | pending | Grok conversation/transcript/composer/tool UI parity not complete. |
| AC-EXT-16 | pending | Remote-computer/context mapping not fully proven. |
| AC-EXT-17 | pending | Same-run extension/worker recovery not proven. |
| AC-EXT-18 | pending | Old primary shell remains current production UI. |
| AC-EXT-19 | pending | Final security review not complete. |
| AC-EXT-20 | pending | Exact-HEAD packaged E2E not run for this architecture. |
| AC-EXT-21 | pending | Final release/Web Store evidence not available. |
| AC-EXT-22 | pending | Grok Bot Chrome effect not yet proven. |
| AC-EXT-23 | pending | Final compliance review pending. |
