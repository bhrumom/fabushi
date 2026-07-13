# Mahayana CLI

`mahayana` is a single distributable product: every release includes a verified
upstream Codex executable at `lib/mahayana/codex`, the Mahayana Rust kernel,
the Telegram runtime, and the web mini-app runtime. Users never install a
separate `codex` command. Programmatic agent turns use the Rust
`codex-client-sdk`, which drives that bundled executable through JSONL and
decodes thread events in Rust. The release pipeline compiles the pinned
Apache-2.0 Codex source revision recorded in `codex-upstream.env`, and includes
its license and source identity in the archive.

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

## Linux online installation

After a `mahayana-v*` GitHub Release is published, install the complete
Mahayana bundle with one command:

```sh
curl -fsSL https://raw.githubusercontent.com/bhrumom/fabushi/main/scripts/install-mahayana.sh | sh
```

The installer selects the `x86_64` or `aarch64` Linux release automatically,
verifies its SHA-256 asset, installs `mahayana` to `~/.local/bin`, and installs
the bundled Codex executable to `~/.local/lib/mahayana/codex`. Complete the
interactive account step with `mahayana login`, then run `mahayana status`.

To install a specific release or choose another destination:

```sh
curl -fsSL https://raw.githubusercontent.com/bhrumom/fabushi/main/scripts/install-mahayana.sh | sh -s -- --version mahayana-v0.1.0 --install-dir /usr/local/bin
```

## Build from source

```sh
cargo build --release --manifest-path native/mahayana-cli/Cargo.toml
./native/mahayana-cli/target/release/mahayana status
```

For a local source-built agent turn, build the verified Codex source and point
the kernel at that development build. Release users do not need this override:

```sh
native/mahayana-cli/sync-upstream.sh /tmp/mahayana-codex
cargo build --release --manifest-path /tmp/mahayana-codex/codex-rs/Cargo.toml -p codex-cli
MAHAYANA_CODEX_BIN=/tmp/mahayana-codex/codex-rs/target/release/codex \
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

The first command uses the bundled Codex MCP command to register `mahayana
mcp-server`; it is the only command that edits the user's Mahayana/Codex MCP
configuration. The second explicitly registers the separately packaged
`global-dharma-mcp` server. Set `GLOBAL_DHARMA_MCP_BIN` when that bundled binary
is not on `PATH`.

`MAHAYANA_CODEX_BIN` is a development and host-integration override only; the
normal release path always uses the embedded Codex executable.
