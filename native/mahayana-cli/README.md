# Mahayana CLI

`mahayana` is a Rust product shell around the installed upstream `codex` CLI.
Programmatic agent turns use the Rust `codex-client-sdk`, which starts Codex
through its JSONL transport and decodes thread events in Rust. It does not
copy, patch, or pin Codex source. `mahayana agent …` (and the compatibility
alias `mahayana codex …`) both use this SDK path and inherit whichever upstream
Codex binary is bundled with the app or selected through `MAHAYANA_CODEX_BIN`.
Upgrading Codex therefore upgrades the agent engine without a Fabushi fork
merge.

The same `mahayana-wrapper` Rust crate is used by the CLI and native app
backends. It dispatches these existing Rust modules rather than reimplementing
them in Dart or TypeScript:

- `fabushi-telegram-runtime` for Telegram state, authentication and transport;
- `fabushi-miniapp-runtime` for mini-app JSON requests and delivery queues;
- `fabushi-miniapp-core` for the shared web mini-app capability policy.

Flutter's existing Telegram and mini-app FFI loaders prefer the unified
`mahayana-wrapper` dynamic library and fall back to the pre-existing individual
libraries if a legacy package has not yet bundled it. The wrapper preserves the
existing C symbols, so the Flutter UI contract does not need to change.

## Build and run

```sh
cargo build --release --manifest-path native/mahayana-cli/Cargo.toml
./native/mahayana-cli/target/release/mahayana status
./native/mahayana-cli/target/release/mahayana agent "Explain this project"
```

For callers that need SDK options such as a saved thread, model, working
directory, sandbox, or approval policy, pass the same JSON request shared by
the native FFI boundary:

```sh
mahayana agent --json '{"prompt":"Inspect this workspace","sandbox":"read-only","approvalPolicy":"never"}'
```

`mahayana mcp-server` is a stdio MCP server. It exposes the Rust Telegram and
web mini-app operations to the upstream Codex TUI. Read-only inspection and
policy checks are available directly; Telegram and mini-app execution require
an explicit `confirmed: true` tool argument.

```sh
mahayana mcp install
mahayana mcp install-global-dharma
```

The first command uses the upstream `codex mcp add` command to register
`mahayana mcp-server`; it is the only command that edits the user's Codex MCP
configuration. The second explicitly registers the separately packaged
`global-dharma-mcp` server. Set `GLOBAL_DHARMA_MCP_BIN` when that bundled binary
is not on `PATH`.

`sync-upstream.sh` and `patches/` remain as an archived optional source-fork
experiment. They are not part of the product build or upgrade path.
