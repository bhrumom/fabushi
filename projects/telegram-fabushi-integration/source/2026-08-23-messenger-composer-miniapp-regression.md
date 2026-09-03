# 2026-08-23 Messenger composer / Mini App regression

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Reported**: `2026-08-23`
- **Source**: user desktop screenshot and explicit repair request

## User-observed behavior

1. In the unified desktop Messenger, selecting **Bot Father** shows an orange top error banner:
   `bridge/invoke-failed: host operation failed: provider failed: agent backend is unavailable: plugin not found: bot-father`.
2. The message composer/input is not visible at the bottom of contact conversations.
3. The requested result is to remove the erroneous failure state by repairing the routing problem, not by merely hiding the error, and to make the composer reliably visible for message contacts.

## Engineering interpretation to verify

- `Bot Father` is surfaced with conversation kind `miniapp`. Mini Apps already have a dedicated `miniapp.open` Host route and dedicated Messenger Mini Apps surface; treating a `miniapp` summary as a generic chat conversation incorrectly sends it through `conversation.open` / the agent backend.
- The chat workspace is a vertical flex container with clipped overflow. The scrolling message region currently has no explicit `min-height: 0`, so its intrinsic minimum can displace the composer below the clipped viewport, especially on an empty conversation with the centered empty-state card.

These interpretations are hypotheses until the task implementation and GitHub Actions regression checks confirm them.
