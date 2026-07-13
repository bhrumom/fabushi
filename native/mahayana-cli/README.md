# Mahayana CLI

`mahayana` is a single distributable product: every release includes a verified
upstream Codex executable at `lib/mahayana/codex`, the Mahayana Rust kernel,
the Telegram runtime, and the web mini-app runtime. Users never install a
separate `codex` command. Running `mahayana` with no subcommand opens the Codex
TUI with the Mahayana MCP server injected for that process, so normal
conversation and all software operations share one dialog. Programmatic agent
turns use the Rust `codex-client-sdk`, which drives that bundled executable through JSONL and
decodes thread events in Rust. The release pipeline compiles the pinned
Apache-2.0 Codex source revision recorded in `codex-upstream.env`, and includes
its license and source identity in the archive.

The same `mahayana-wrapper` Rust crate is used by the CLI and native app
backends. It dispatches these existing Rust modules rather than reimplementing
them in Dart or TypeScript:

- `fabushi-telegram-runtime` for Telegram state, authentication and transport;
- `fabushi-miniapp-runtime` for mini-app JSON requests and delivery queues;
- `fabushi-miniapp-core` for the shared web mini-app capability policy.
- `mahayana-product-client` for Alipay account sessions, contacts, friend
  requests, and direct messages.

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
software account step with `mahayana login`; this opens the existing Fabushi
Alipay authorization flow. `mahayana codex-login` is available separately only
when the bundled upstream Codex account itself needs authentication.

To install a specific release or choose another destination:

```sh
curl -fsSL https://raw.githubusercontent.com/bhrumom/fabushi/main/scripts/install-mahayana.sh | sh -s -- --version mahayana-v0.1.0 --install-dir /usr/local/bin
```

## Build from source

```sh
cargo build --release --manifest-path native/mahayana-cli/Cargo.toml
./native/mahayana-cli/target/release/mahayana status
```

## Product commands

```sh
mahayana                         # Codex TUI + Mahayana tools
mahayana login                   # open Alipay and wait for the one-time callback
mahayana login complete CODE     # exchange an authorization code
mahayana auth status
mahayana contacts list
mahayana contacts search 关键词
mahayana contacts add USER_ID "验证消息"
mahayana contacts requests
mahayana contacts accept REQUEST_ID
mahayana messages list USER_ID
mahayana messages send USER_ID "你好"
mahayana miniapp chat MINIAPP_ID "你好"
```

The software session is stored under `~/.mahayana/session.json` (or
`$MAHAYANA_HOME/session.json`). Set `MAHAYANA_API_BASE_URL` only for a trusted
first-party development environment. CLI and MCP output redact tokens and
authorization codes.

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

`mahayana mcp-server` is a stdio MCP server. It exposes software auth,
contacts, messages, Rust Telegram, and web mini-app operations to the upstream
Codex TUI. State-changing tools require an explicit `confirmed: true` argument.
The default TUI injects this server without editing global Codex configuration.

```sh
mahayana mcp install
mahayana mcp install-global-dharma
```

The first command uses the bundled Codex MCP command to persistently register `mahayana
mcp-server`; it is the only command that edits the user's Mahayana/Codex MCP
configuration. The second explicitly registers the separately packaged
`global-dharma-mcp` server. Set `GLOBAL_DHARMA_MCP_BIN` when that bundled binary
is not on `PATH`.

`MAHAYANA_CODEX_BIN` is a development and host-integration override only; the
normal release path always uses the embedded Codex executable.

The Flutter desktop installer workflow places the same CLI, pinned Codex
binary, and `mahayana-wrapper` library inside the macOS, Linux, and Windows app
bundles. Mobile packages link the wrapper directly; because iOS and Android do
not permit launching the bundled desktop Codex process, agent-style mini-app
turns use the protocol-compatible first-party cloud gateway there.
