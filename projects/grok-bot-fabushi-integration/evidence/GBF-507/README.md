# GBF-507 Evidence Index

## Source requirement

- `projects/grok-bot-fabushi-integration/source/grok-bot融合优化.txt`
- `projects/grok-bot-fabushi-integration/source/完整telegram融合进fabushi.txt`
- User continuation on 2026-08-25: complete Grok-style UI/behavior fusion, route Bot work through Mahayana multi-step runtime, persist conversations/runs, and drive the dynamic avatar from real execution state.

## Reference and provenance

- Reference repository: `bhrum/grok-bot-0.18-reconstructed`
- Pinned reference commit: `a9f633e09d49a85829b8236331b9e21f7e612634`
- Reuse decision: clean-room observable behavior / API adaptation only. No production renderer, installer payload, vendor visual asset, trademarked product identity, or unlicensed source is copied into Fabushi.

## Implementation and repair pull requests

| PR | Result / role |
|---|---|
| `#2108` | Initial Mahayana Agent Workbench, multi-step runtime projection, actions and live BotMark state |
| `#2110` | Stabilized projected transcript semantics and restart E2E; merged as `75a7d5e94e6ffcff8dcac3af09febfbfe9f6781b` |
| `#2111` | Restored Mahayana conversation text and removed duplicate projected text; merged as `7fb1cd1f5749bb206dd3cf04da5c78612d6e6d25` |
| `#2112` | Repaired exact-main transport regression fixture and added protocol-level self-hosted Bot -> Mahayana bridge; merged as released product SHA `e2332b09475f1032567b27d454c45b3801cbd9c5` |

## Important failure evidence retained

- Exact-main Electron run `32803828364` on `7fb1cd1f...` **failed before Release** in the real Linux Rust Host journey.
- Root cause: a direct Node regression supplied a synthetic `window` without browser EventTarget methods after Electron transport legitimately began observing command events.
- The failure was not waived. PR `#2112` repaired the fixture and, during the same audit, closed the real product gap where normal self-hosted Bot peers were not reliably entering Mahayana.

## Final-head PR evidence for #2112

- Electron desktop PR gate `32805007332`: **success**.
- CI `32805007394`: **success**.
- Messaging Product Gate `32805007346`: **success**.
  - Rust self-hosted messaging library tests: success.
  - `human_group_message_requests_bot_execution_inside_messaging_service`: proves human message -> `botInvocationRequested` producer path.
  - Rust format/Clippy/media-transfer checks: success.
  - Electron Messenger TypeScript/architecture: success.
  - production Feature Host bridge: success.
- Merge-group verification `32805134081`: **success**.

## Canonical-main exact-SHA evidence

Released product SHA: `e2332b09475f1032567b27d454c45b3801cbd9c5`.

### Messaging

- Exact-main Messaging Product Gate `32805236171`: **success**.

### Electron desktop

- Exact-main Electron desktop quality gate `32805236227`: **success**.
- Real Linux Rust Host complete user journey before packaging: **success**.
- Packaged Linux complete user journey: **success**.
- Packaged Windows complete user journey: **success**.
- macOS Developer ID signing: **success**.
- macOS notarization/stapling verification: **success**.
- Packaged macOS complete user journey: **success**.
- Workflow uploaded screenshots/video/trace/Playwright diagnostics and installable packages.
- The exact-main Workbench suite includes a self-hosted message + canonical `botInvocationRequested` consumer journey that produces a completed Mahayana multi-step run with >=3 lifecycle/step nodes, a result-state avatar, accepted idempotency claim and restart recovery.

### Native mobile

- Exact-main Native mobile quality gate `32805236162`: **success**.
- Android unit/lint/debug packaging: **success**.
- Pixel 7 emulator Compose simulated-user tests: **success**.
- iOS SwiftUI unit + simulated-user UI tests: **success**.
- iOS `.xcresult` uploaded: **success**.

## Release evidence

- Post-main delivery run `32805840960`: **success**.
  - exact-main desktop/mobile binding: success.
  - tested macOS/Windows/Linux artifact download: success.
  - exact-SHA manifests/updater validation: success.
  - immutable tested Release creation: success.
  - delivery ledger persistence: success.
- Release: `desktop-1.0.896` / **Fabushi Desktop 1.0.896**.
- Release target SHA: `e2332b09475f1032567b27d454c45b3801cbd9c5`.
- Published at: `2026-08-25T03:37:51Z`.
- Required updater/install assets observed:
  - `fabushi-1.0.896-macos-arm64.dmg`
  - `fabushi-1.0.896-macos-arm64.zip`
  - DMG/ZIP blockmaps
  - `latest-mac.yml`
  - `fabushi-1.0.896-setup.exe` + blockmap
  - `latest.yml`
  - `fabushi-1.0.896-x86_64.AppImage`
  - `fabushi-1.0.896-amd64.deb`
  - `latest-linux.yml`
  - `fabushi-delivery-mac.json`, `fabushi-delivery-win.json`, `fabushi-delivery-linux.json`
  - `SHA256SUMS.txt`

## Acceptance checklist

- [x] Required PR checks successful on exact final head
- [x] Protected merge / merge-queue verification
- [x] Canonical-main `mahayana-agent-workbench.spec.ts` via real Rust Host
- [x] Self-hosted Bot producer (`botInvocationRequested`) and Mahayana consumer path verified
- [x] Packaged macOS/Windows/Linux Electron journeys
- [x] Android/iOS simulated-user journeys
- [x] Screenshot/video/trace/diagnostic evidence uploaded by canonical-main workflow
- [x] Post-main updater manifests validated
- [x] Immutable GitHub Release targeting the exact tested main SHA
- [x] Canonical project/task/acceptance/WBS/status/changelog closure records prepared

## Boundary note

`GBF-507` is RELEASED. This evidence does **not** claim that local journals are the final persistence authority. `GBF-601` / `GBF-602` remain responsible for the final Rust canonical conversation/run schema and crash/replay-safe checkpoint model. `GBF-805` remains the full reconstructed observable-parity closure for the broader project.
