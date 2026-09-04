# ADR-0003 — one canonical Bot identity owns one durable Mahayana session

- Project: `FAB-P0005/MSR`
- Program: `FAB-ARCH-P0-20260904`
- Status: Proposed for protected-main review
- Date: 2026-09-04

## Decision

MSR is the exclusive Bot execution owner. Each canonical Bot identity has one durable Mahayana session key. Conversation/group/topic context is namespaced turn context within that session, never a second runtime. MiniApp install/update must bind/reuse this session idempotently.

All capabilities, including same-account devices and MiniApps, enter through MSR policy/approval/audit and return typed result envelopes.

## Rejected
Per-conversation runtimes, provider-owned sessions as product identity, and MiniApp-specific hidden Bot engines.