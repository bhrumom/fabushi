# 2026-09-18 — MSR-105 first-turn readiness continuation

## User requirement

The desktop app must be **actually ready to work before the user sends the first message**. It is not sufficient to render Mahayana, the composer, a cached Bot row, or a synthetic “thinking” state while the real provider/session is still cold. The user specifically reported that after launch a message can be submitted and then wait a long time before the Mahayana runtime visibly starts.

## Required behavior

- Start/prepare the real Mahayana provider session during authenticated Host readiness, not from the first `chat.send`.
- A restored logged-in session and a fresh password/browser/OAuth login must both cross the same readiness boundary.
- Warmup must not send a model prompt, create a fake reply, or mutate the visible conversation transcript.
- Repeated readiness checks must reuse the same provider session rather than creating multiple Agent threads.
- The existing desktop send button remains disabled while `hostReady=false`; therefore `hostReady` must only become observable after the signed-in Mahayana session is genuinely prepared.
- First-message latency after readiness should consist of actual turn execution/model time, not process/thread/session cold start.

## Open-source-first evidence

Reviewed current upstream patterns before implementation:

- OpenAI Codex `7498521d288b9b3b96ffba4eedf089d8d6e06a84`, `codex-rs/core/src/session/session.rs`: independent startup work is kicked off in parallel specifically to reduce startup latency instead of deferring it to the first turn.
- xAI Grok Build `a28ee2b2063426e8816e380ccea528b9de95e5da`, `crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md`: the documented lifecycle is `Initialize -> Create session -> Send prompts`.

Fabushi adapts that lifecycle principle through its own Rust provider/runtime/Host contracts. No upstream source code or new dependency is copied.
