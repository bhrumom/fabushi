# TFI-M7-P0-001 — group Bot mention/privacy/session/tool-result transport

- Project ID: `FAB-P0001`
- Task ID: `TFI-M7-P0-001`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependencies: `TFI-M6-P0-005`, `MSR-210`, `GBF-508` all REVIEW-PASS

## Objective

Implement the TFI transport/projection half of Grok-like group Bot behavior using the clean-room GBF contract and the single MSR runtime.

## Contract

- privacy-mode Bot triggers only on explicit mention, reply-to-Bot, registered slash/command or other GBF-approved directed signal; ambient group messages are ignored for invocation.
- non-privacy mode, if explicitly configured, may receive broader context under documented policy.
- one Bot retains one Mahayana session; group/conversation/topic scope is context inside it.
- tool request/approval/progress/result/error are typed events/messages with request correlation and visible provenance, not hidden side effects or raw implementation logs.
- member/bot permissions and denied tools fail closed.

## Acceptance

Positive/negative group trigger tests, topic context, reply/mention, ambient ignore, tool denial/result, restart continuity and packaged multi-user simulated journey. Full video must prove both invocation and non-invocation cases.