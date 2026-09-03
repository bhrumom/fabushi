# 2026-08-25 — GBF-507 Mahayana Agent Workbench

## Added

- Fabushi-owned Mahayana Agent Workbench inside the canonical Messenger.
- Runtime projections for operation lifecycle, model route, Agent steps, streaming messages, transcript cards, MCP results, approvals, subagents, asynchronous tasks, background agents and usage.
- Real runtime-state-driven BotMark avatars in the active peer row, conversation Header and profile panel.
- Persistent bounded run journal with conservative restart interruption and explicit resume.
- In-conversation stop, approval and resume actions.
- Grok-style dark translucent run timeline and conversation material implemented with Fabushi React/CSS/Motion code.
- Playwright journey covering multi-step visibility, final avatar state and close/relaunch run restoration.

## Changed

- Electron Mahayana `chat.send` commands are normalized to `mode=agent`.
- Self-hosted Bot composer submissions route to Mahayana rather than remaining a messaging-only exchange.
- Messenger conversation status reflects the current Mahayana step/result/error/approval state.

## Security and provenance

- Mahayana remains the only execution and permission authority.
- Unfinished runs are not automatically replayed after restart.
- No Grok production renderer, installer payload or vendor visual asset is copied into Fabushi.

## Delivery

- Branch: `feat/gbf-mahayana-agent-workbench-v1`
- PR: `#2108`
- State: implementation present; final-head CI, protected merge and canonical-main package/E2E evidence pending.
