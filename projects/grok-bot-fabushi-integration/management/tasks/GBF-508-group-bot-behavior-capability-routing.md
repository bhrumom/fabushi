# GBF-508 — Grok-like group Bot behavior and same-account capability routing

- Project ID: `FAB-P0004`
- Task ID: `GBF-508`
- Program: `FAB-ARCH-P0-20260904`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependency: `MSR-210 REVIEW-PASS`; reuse existing GBF-409/411; coordinate with MSR-211
- Parallel: may develop behavior contracts while TFI M6 runs, but integration waits for dependencies.

## Goal

Define and implement Fabushi-owned clean-room Bot behavior matching required Grok-like interaction boundaries, while routing same-account device and MiniApp actions through MSR.

## Required behavior

- privacy mode: invoke on explicit mention, reply-to-Bot, registered command/slash or approved directed trigger; ignore ambient messages;
- one Bot uses its one MSR durable session across direct/group/topic scopes;
- render/model states distinguish thinking/progress, tool request, approval pending, tool result/error and final response with stable invocation IDs;
- use GBF-409 for account device presence/pair/control and GBF-411 for semantic App/WebMCP surface; never equate login with control;
- expose installed MiniApp capabilities only after MSR policy/catalog admission; no direct provider->message side channel;
- Computer Use is fallback when semantic MiniApp/App tools are unavailable and authorization permits.

## Clean-room rule

Behavior reference revision: `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`. Root LICENSE absent; source copying is forbidden. Record observable behavior anchors only.

## Acceptance

Contract tests cover mention/reply/command/ambient ignore, two groups same Bot session continuity, two Bots isolation, typed tool-result progression, approval deny/expire, revoked/stale device, MiniApp unavailable and semantic->Computer Use fallback. GitHub Actions and packaged simulated-user video/trace/report required. Update TFI-M7-P0-001 and MSR-211 records with exact integrated contracts.