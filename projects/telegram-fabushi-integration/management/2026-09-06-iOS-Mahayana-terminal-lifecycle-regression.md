# iOS Mahayana terminal lifecycle regression — 2026-09-06

## Scope

- Project: TFI
- Platform: iOS Simulator
- Discovery run: https://github.com/bhrumom/fabushi/actions/runs/34014067510
- Exact source SHA: `3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`
- Comparable app version: `1.2.35`, iOS build `29`
- App-owned test device: `gha-34014067510-1-interactive`
- Device provenance: GitHub Actions run `34014067510`, attempt `1`, kind `github-actions-ios-app`; protected test account was authenticated after exact app installation and the installed app registered the gateway itself.
- Forbidden devices were not used: no KRIS, no old device, no runner-owned gateway.
- No local build, Simulator, UI test, or native test was run.

## Evidence before the regression

The same exact run successfully exercised all six registered semantic tools through the App-owned iOS gateway: `fabushi.app.status`, `fabushi.app.snapshot`, `fabushi.app.find`, `fabushi.app.action`, `fabushi.app.wait`, and `fabushi.app.assert`.

The live matrix created two real channels inside the App (`TFI iOS A`, `TFI iOS B`) and exercised conversation pin/mute, text send, reply, edit, reaction, message pin, forward, poll compose/send/vote, contact-share empty state, location-share retry/cancel, and chat sync. This avoided runner-side injection of business fixtures.

## Reproduction

1. Open Mahayana through `mahayana-agent-entry`.
2. Set `mahayana-draft` to `iOS 1.2.35 stop E2E：请持续思考并连续输出，直到我点击停止。`.
3. Wait until `mahayana-send` is enabled and invoke it.
4. The live surface produced user entry `mahayana-entry-ios-chat-fd39efe3-f39f-48ba-8f43-0a3744886ca2` and model-route action `mahayana-entry-action:operation:324a18d8-aaac-4177-9a52-6a7fa39ac9e9:model-route`.
5. At generation `95`, `mahayana-stop` was absent while `mahayana-send` was present but disabled. A subsequent wait for enabled `mahayana-send` also failed.

This proves a real operation had been accepted/routed, but the UI had already left the `chatBusy` state before any observed `operation.completed`, `operation.failed`, or `operation.interrupted` terminal event.

## Root cause

PR #2389 removed the unconditional post-pump lifecycle reset but retained a heuristic after `pumpChatEvents`: if the operation's `thinking` row was absent, `sendChat` cleared `chatBusy` and `activeOperationId`. `chat.message` and `chat.delta` intentionally remove the thinking row before the operation is terminal. If the receive pump then returns because of a non-terminal receive interruption, timeout, or task cancellation, the absence of `thinking` is not evidence of a terminal operation. The UI therefore switches from the Stop control back to a disabled Send control while the operation still exists.

## Atomic fix

Branch: `fix/tfi-ios-mahayana-terminal-lifecycle-20260906`

- Make `pumpChatEvents` return an explicit terminal/non-terminal outcome.
- Only `operation.completed`, `operation.failed`, and `operation.interrupted` return terminal.
- `sendChat` clears `chatBusy` / `activeOperationId` only for the terminal outcome (or when command submission failed before an operation was established).
- Receive interruptions retry within the existing bounded pump and cannot be converted into terminal state.
- Task cancellation and pump timeout return non-terminal and preserve the active lifecycle.
- Add a narrow native contract test locking the terminal-only settlement rule.

## Acceptance gate

1. Narrow GitHub Actions/native contract tests pass on the exact PR head; no local build/test.
2. Merge only through the PR/protected-main path.
3. After merge, increment the test version and publish a new comparable iOS Simulator test artifact in GitHub Actions.
4. Start native recording before installation, authenticate the protected test account only after installation, and require the installed App to self-register the new gateway.
5. Select only the new run-bound App-owned iOS device with `fabushi test`.
6. Invoke all six semantic tools and re-run the complete reachable iOS matrix.
7. For Mahayana, send a long-running request, observe `mahayana-stop`, invoke Stop, then observe terminal settlement and Send becoming available again.
8. Preserve video, step screenshots, device trace, xcresult, app/Simulator logs, report, and exact test-build digest as GitHub Actions artifacts.
