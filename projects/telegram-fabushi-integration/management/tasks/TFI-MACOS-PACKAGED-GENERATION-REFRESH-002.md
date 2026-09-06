# TFI-MACOS-PACKAGED-GENERATION-REFRESH-002

- Project: `FAB-P0001 / TFI`
- Triggering canonical main: `71168adbeea65e998bb650ba3a4636911287636a`
- Electron run: `34058850412`
- macOS job: `101555620505`
- macOS diagnostics artifact: `9996959351`
- Status: in progress

## Observed failure

The exact-main macOS package was signed, notarized, stapled and verified successfully. Its packaged Playwright suite then failed `desktop/e2e/app-agent-surface.spec.ts` twice with a one-generation race:

- first attempt: `stale_app_surface_generation: expected 76, received 75`
- retry: `stale_app_surface_generation: expected 86, received 85`

The failing mutation uses `messageSnapshot.generation` after a bounded 500-element snapshot has already proved that the stable `semanticMessageAgentId` is outside that snapshot. Asynchronous App updates may advance the live generation before the mutation. The server is correct to reject the stale generation.

The same packaged run passed the Global Dharma packaged Mini App journey; this blocker is independent of Marketplace/Bot/WebMCP/account/payment semantics.

## Atomic repair

1. Preserve the bounded snapshot assertions: `truncated=true` and target absent from the 500-element snapshot.
2. Immediately before invoking the stable `semanticMessageAgentId`, run an exact `find` for that same agent ID.
3. Require exactly one match and require its returned agent ID to equal the stable target.
4. Use only the fresh `find.generation` for the subsequent mutation.
5. Do not retry stale actions, weaken generation fail-closed, or rebind positional refs.
6. GitHub Actions only for validation; no local build/test.

## Acceptance

- [ ] Atomic PR head required CI is green.
- [ ] Protected merge queue merges the fix; no bypass/direct merge.
- [ ] New canonical-main Electron macOS packaged journey passes this App MCP test.
- [ ] The independent returning-user one-second failure remains a separate task/PR if still reproducible.
- [ ] Global Dharma exact-main packaged evidence remains aligned to the resulting canonical SHA; missing evidence remains `PENDING`.
