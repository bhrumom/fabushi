# TFI-M8-P0-002 — MiniApp install -> visible Bot -> Mahayana session binding

- Project ID: `FAB-P0001`
- Task ID: `TFI-M8-P0-002`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependencies: `TFI-M8-P0-001 REVIEW-PASS`, `MSR-210 REVIEW-PASS`

## Objective

Make MiniApp installation atomically/idempotently establish and display the corresponding Bot while binding Bot execution to its one MSR Mahayana session.

## Existing boundary

Reuse `desktop/src/miniapp-bot-projection.ts`; it already derives Bot id/username/displayName/description/conversationId/naturalLanguage/menu/commands/calls from canonical Marketplace metadata. Do not add a duplicate contact/Bot database.

## Required behavior

- Successful install causes the derived Bot to appear in Messenger without restart; restart reconstructs it from installed state.
- reinstall/update does not create a second Bot or second Mahayana session.
- uninstall/disable behavior is explicit and tested; historical conversation handling must not orphan execution identity.
- missing/invalid manifest Bot metadata fails visibly rather than fabricating an identity.
- opening/chatting with the Bot routes through MSR session binding and existing policy/tool bridge.

## Acceptance

Focused projection/idempotency/session-binding contracts + packaged card/install -> Bot visible -> chat -> MiniApp open journey, plus full pass/fail visual/trace evidence. Cross-project task IDs and actual session ID mapping are written back.