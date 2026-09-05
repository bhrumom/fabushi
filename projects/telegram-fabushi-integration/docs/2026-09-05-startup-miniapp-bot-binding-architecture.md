# FAB-ARCH-20260905-01 — TFI architecture delta

Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`

TFI remains the owner of canonical messaging and MiniApp lifecycle semantics. This delta deliberately reuses `M3-DESKTOP-002`, M8 Marketplace/BotFather, account sync, `M8-MARKET-002`, `native/mahayana-messaging` and the single Messenger shell.

## Current facts

- Existing startup design already persists a local projection and has a packaged `<1000 ms` returning-user performance gate. The current ~1 minute complaint is therefore treated as a regression/critical-path diagnosis, not a fresh startup architecture.
- `MiniAppManifest` already has version, requested permissions and optional `bot_actor_id`; `MiniAppGrant` and `MiniAppSession` already exist.
- Installed Marketplace MiniApp Bots are already projected into Messenger peers by M8-MARKET-002, but current canonical types do not encode a durable install id/version digest/status/audit record plus one-to-one install-to-Bot/conversation invariant.
- Bot generation currently has a marketplace generation workflow/draft result, but no canonical chat-card entity result contract.

## TFI target boundaries

1. Startup: projection first; Host/auth/snapshot/event/background reconcile never serialize first paint unnecessarily. Diagnose with phase trace before fix.
2. MiniApp entity: immutable version+manifest digest, durable install lifecycle and derived card projection.
3. Binding: each account-scoped current MiniApp install has exactly one default Bot actor and one direct conversation; lifecycle transitions are auditable and synced across devices.
4. Group protocol: conversation ordering and multi-Bot result events are canonical messaging data; Mahayana orchestration remains outside TFI.

## Rollback principles

Schema additions must be backward-readable or migrated with a reversible compatibility period; a card projection can be disabled without deleting install data; uninstall must not delete unrelated conversations; startup fix must preserve the projection-first fallback and can be reverted independently from diagnostics.

See the MSR master architecture document for shared IDs, ToolExecutionContext, session generation and DAG.
