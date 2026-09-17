# M3-DESKTOP-003 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `M3-DESKTOP-003`
- Architecture revision: `FAB-ARCH-20260905-01`
- Architecture base: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- Execution branch: `feat/tfi-m3-desktop-003-startup-diagnostics`
- Execution state: `READY_FOR_TEST`
- Scope: diagnostic/test-only; no root-cause claim; no startup or message semantics change

## Implementation evidence

The execution branch adds a renderer-side monotonic startup trace and extends the existing packaged returning-user Messenger E2E. The trace is exposed only as diagnostic data and does not alter transport return values, exceptions, command payloads, event ordering, messaging protocol/schema, Host lifecycle semantics, or message behavior.

### P0-P9 observation map

| Phase | Observation | Source seam |
| --- | --- | --- |
| P0 | renderer navigation / time origin | `desktop/src/selfhosted-messaging-client-v2.ts::initializeStartupCriticalPathDiagnostics` |
| P1 | renderer projection cache read, hit/miss, bytes, duration | same |
| P2 | double-rAF first frame plus paint entries | same |
| P3 | existing transport `authStatus()` resolution/rejection duration | `instrumentStartupTransport.authStatus` |
| P4 | existing transport `initialize()` resolution/rejection duration | `instrumentStartupTransport.initialize` |
| P5 | first `sync` request + first `syncBatch`, counts/bytes/cursor/duration | `SelfHostedMessagingClientV2.sync`, `asMessagingHostEvent` |
| P6 | first snapshot conversation/actor metadata completion | `asMessagingHostEvent` |
| P7 | first message projection formatting followed by next animation frame | `messagingText` |
| P8 | first subscribed runtime event + first sync backlog counts/bytes | `instrumentStartupTransport.subscribe`, `asMessagingHostEvent` |
| P9 | second/background `sync` request and completion duration | `SelfHostedMessagingClientV2.sync` |

Renderer Long Task observation uses `PerformanceObserver(type=longtask, buffered=true)` when supported. If the runtime does not support the entry type, the trace records an explicit unsupported reason rather than inventing a measurement.

## Packaged E2E evidence contract

The existing returning-user startup test now:

1. creates the existing real self-hosted startup channel through the product UI;
2. uses the real messaging Host command path to seed `32` text messages, exceeding the current initial snapshot message limit `20` without adding a test-only product bypass;
3. waits for both renderer projection and native durable projection to contain the seeded history;
4. fully closes and relaunches Electron using the same app-data directory;
5. requires the projected conversation and newest seeded message to be visible through the product UI;
6. waits until P0-P9 are present in the runtime diagnostic trace;
7. preserves existing `startup-performance.json` and additionally writes/attaches `startup-critical-path.json` plus a full-page screenshot.

`startup-critical-path.json` records the exact CI SHA when `GITHUB_SHA` is present, platform, packaged/not-packaged flag, history seed count, raw P0-P9 entries, long-task entries, counts/bytes and durations. It deliberately stores `rootCauseClaim: null` until a real packaged run is reviewed.

## Modified files

- `desktop/src/selfhosted-messaging-client-v2.ts`
- `desktop/e2e/messenger.spec.ts`
- `projects/telegram-fabushi-integration/management/tasks/M3-DESKTOP-003-startup-first-message-diagnostics.md`
- `projects/telegram-fabushi-integration/evidence/M3-DESKTOP-003/README.md`

No MiniApp, Mahayana CLI, GBF device-control, native messaging protocol/core, workflow, release/version, auth-semantics, or Host-lifecycle file is modified.

## Risk

- Diagnostic wrapper overhead can perturb timings slightly. Mitigation: only primitive timestamps/serialized-size accounting are added; wrappers forward original values and rethrow original failures.
- `JSON.stringify` byte estimation can add work for a large sync batch. It is diagnostic-only and is removable as one task-scoped change.
- Chromium Long Task entries can be unavailable on a given packaged runtime. The trace records support status/reason explicitly.
- P7 is an observation of the first message entering the existing renderer formatting/render path, not a claim that this phase is the bottleneck.

## Rollback

Revert the M3-DESKTOP-003 execution commits/PR. There is no schema migration, durable-state migration, protocol change, workflow change, or release/version change. Removing the instrumentation and E2E extension restores the architecture-base behavior.

## CI / E2E acceptance pending

No local build, native test, E2E, or packaging was run, per task policy. PR-head GitHub Actions must validate:

- Electron renderer TypeScript/typecheck and existing desktop quality gates;
- existing messaging/unit/product gates;
- packaged Electron Messenger E2E on the exact PR head;
- `startup-performance.json` preservation;
- `startup-critical-path.json` contains P0-P9 or an explicit unobservable reason for any unsupported marker;
- Playwright trace, video, screenshot, app/main logs, and exact head SHA are retained;
- the packaged run either reproduces the delayed-completion symptom or records that it did not reproduce;
- only after that run may the measured bottleneck classification and implicated exact file/function be written. No timing constant alone is accepted as a root-cause claim.
