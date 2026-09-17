# OpenBot UI and reply fusion

Status: implementation branch `feat/openbot-ui-reply-fusion-20260913`

## Upstream reference

- Repository: `CopilotKit/OpenBot`
- Reference snapshot inspected for this work: `19fdcbb7fd5c072d5c2aa95800fcbbbf72aa202c`
- License: MIT
- Product reference: `https://openbot.run/`
- Visual reference: user-supplied OpenBot screenshot in Fabushi task `063f7af4-b6d4-41cf-81d7-8bd6ae27f35b`

OpenBot source is used as a design/behavior reference. Fabushi does not embed OpenBot's runtime, generated assets, or application shell in production. The implementation stays inside Fabushi's existing Mahayana/Messenger runtime and renderer boundaries. If source is ever copied rather than independently reimplemented, the upstream MIT copyright/license notice must travel with the copied material.

## What was mapped

### Workspace and navigation

OpenBot uses a dark, matte workspace with a compact coworker rail, a searchable conversation roster, and a single main thread. Fabushi now maps those characteristics onto the existing `messenger-workspace` instead of introducing another product shell:

- compact dark rail and channel roster;
- subtle selected/hover surfaces rather than Telegram-blue selection blocks;
- compact search field;
- flat dark conversation canvas without the legacy Telegram wallpaper;
- low-contrast borders and elevated surfaces;
- dark information panel and composer;
- circular high-contrast send action.

Implementation: `desktop/src/openbot-ui-parity.css`.

### Coworker / Bot identity

OpenBot gives coworkers distinct, immediately recognizable geometric identities. Fabushi already owns a richer stateful identity engine (`BotMark`) with eyes, canonical aliases, color, activity states, reduced-motion support, and runtime-driven animation.

Instead of importing OpenBot avatar assets, the canonical Fabushi Bot identity now deterministically selects one of the eight silhouettes already supported by the Fabushi engine:

`blob`, `pebble`, `squircle`, `tablet`, `wedge`, `hex`, `cloud`, `teardrop`.

The selection is derived from canonical identity, so a Bot keeps the same silhouette across roster, header, transcript, restarts, and alias re-resolution. Existing deterministic color selection is retained.

Implementation: `frontend/apps/web/src/app/host/bot-mark.tsx`.

### Reply work and progress

OpenBot's useful interaction model is not just final prose: a coworker visibly works inside the thread. Fabushi already has the necessary canonical message/runtime states:

1. a `thinking` transcript row is opened for an active operation;
2. tool/action progress is projected as `action` rows tied to the same `operationId`;
3. success/failure changes the action state without inventing a second transcript model;
4. assistant completion removes the temporary thinking row and leaves the durable result;
5. attachments, source/file cards and Mini App artifacts remain part of the same conversation.

The OpenBot parity layer changes how those states are presented: smaller neutral working indicators, compact tool/action rows, quiet completed steps, clear failures, and a broad final answer card. It does not synthesize chain-of-thought or bypass the existing policy/approval/audit boundary.

Primary implementation remains `desktop/src/messaging-shell-v2.tsx`; presentation is in `desktop/src/openbot-ui-parity.css`.

## Runtime boundary

Mahayana remains the sole executor. This change deliberately does **not** create an `OpenBotRuntime`, second tool gateway, second persistence store, or parallel conversation implementation. Existing Fabushi runtime events, identity aliases, host transport, approvals, audit, artifacts and Mini Apps remain authoritative.

The separate draft work item/PR for broader OpenBot/Hermes task-delivery primitives can continue to add durable lifecycle/delivery/control capabilities behind the same canonical runtime. This visual/reply fusion is compatible with that work and does not make it a prerequisite for desktop rendering.

## Files in this slice

- `desktop/src/openbot-ui-parity.css` — OpenBot-style desktop visual and reply-state presentation.
- `desktop/src/main.tsx` — activates the parity layer after the previous Grok parity stylesheet so OpenBot is the final desktop product skin.
- `frontend/apps/web/src/app/host/bot-mark.tsx` — deterministic identity silhouettes using the existing Fabushi renderer.
- `desktop/scripts/assert-openbot-parity.mjs` — static contract gate for imports, visual selectors, identity silhouettes and reply lifecycle primitives.

## Acceptance

The implementation is not considered released merely because this branch exists. Required validation is:

1. `npm --prefix desktop run test:openbot-parity` passes.
2. `npm --prefix desktop run build:renderer` passes (TypeScript + Vite/CSS integration).
3. Existing desktop E2E remains green, including login/onboarding, messenger, Grok parity, Mahayana workbench, Mini App and semantic-agent gates.
4. A packaged desktop run shows the OpenBot-style dark shell, stable geometric Bot identities, thinking/action/result transitions, attachments/source cards and composer without breaking existing messaging semantics.
5. Merge follows the repository's normal protected PR/CI process; release/versioning stays in the release workflow rather than this feature slice.
