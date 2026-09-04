# MSR-210 — canonical Bot identity -> one durable Mahayana session

- Project ID: `FAB-P0005`
- Task ID: `MSR-210`
- Status: `NOT_STARTED`
- Owner: Execution project group
- Dependencies: existing MSR-201 session/recovery contracts
- Parallel: yes with TFI M6/startup/card and GBF behavior-spec work

## Goal

Provide one authoritative, idempotent mapping from canonical Bot identity to durable Mahayana session.

## Modules

First locate current session registry/supervisor/orchestrator/agent bridge and Bot invocation bridge on exact head; task file does not authorize a parallel registry.

## Required semantics

- create-or-get by stable Bot identity; restart/reopen preserves mapping;
- MiniApp install/reinstall/update reuses mapping;
- direct chat, group, channel/topic use context scopes within same session;
- concurrent turns preserve correlation and policy; interruption/recovery uses existing MSR semantics;
- delete/disable/uninstall lifecycle is explicit and cannot orphan an executable hidden session.

## Acceptance

Unit/conformance tests for idempotency, restart, two conversations same Bot, two Bots isolation, MiniApp update, interrupted recovery and invalid identity. GitHub Actions only. PR updates TFI/GBF dependent task records with actual session contract.