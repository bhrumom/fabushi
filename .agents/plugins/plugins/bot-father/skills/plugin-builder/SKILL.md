---
name: plugin-builder
description: Use Codex inside Mahayana CLI to generate, diagnose, repair, test, package, install, and publish MCP plugin mini-apps.
---

# Bot Father plugin workbench

Use the current Codex workspace as the source of truth. Read every applicable
`AGENTS.md` before editing and preserve unrelated changes.

For a new plugin, run `mahayana plugin init <name> --profile <profile>` and then
customize the generated package. Keep it under
`.agents/plugins/plugins/<name>` and register it in
`.agents/plugins/marketplace.json`.

Every generated plugin must contain a valid Codex manifest, MCP configuration,
Mahayana extension manifest, MCP Tools, MCP App UI, content, tests, and a
packaging route. Prefer two runtime variants:

- a local CLI or stdio runtime for CLI/desktop that can start without a chat UI;
- an HTTPS or WASM runtime for mobile/web distribution.

Treat host bridges as explicit, narrow capabilities. Never grant a plugin raw
host handles, credentials, or blanket approval. Destructive, financial,
credential, privacy, camera, microphone, location, screen, accessibility, and
administrator actions must not be silently approved.

Before finishing, run `mahayana plugin validate`, `mahayana plugin test`, and
`mahayana plugin pack` against the generated plugin, plus the relevant
repository tests. The CLI test command must execute the plugin's declared test
suite; an external `npm test` alone is not a substitute. Exercise the local
runtime over stdio, and verify MCP App message handling does not mistake an
outbound JSON-RPC request for its response.

For an official in-repository plugin, do not hand-edit
`frontend/apps/web/public/.well-known/mahayana/marketplace.json` or the
Marketplace approval ledger. Commit the plugin source plus the internal
`.agents/plugins/marketplace.json` registration in a governed PR. The required
`CI result` automatically runs `Marketplace Security Review` (deterministic
Fabushi policy, CodeQL, Semgrep CE, Trivy, OSV and Syft/Grype). Only after that
PR is protected-merged to canonical `main` may `Marketplace Auto Publish`
generate the public catalog and approval ledger in its own protected publish
PR. A failed audit, a changed digest under an already-approved version, or a
failed publish PR keeps the new plugin/version unlisted.

Use `mahayana plugin publish` only after local plugin validation/test/pack has
passed and when the market service path being used is explicitly supported by
the current repository policy. Only report public publication after the
canonical public market query returns the exact plugin/version and its audit
digest; a source PR, successful pack, or pending auto-publish PR is not a
publication receipt.
