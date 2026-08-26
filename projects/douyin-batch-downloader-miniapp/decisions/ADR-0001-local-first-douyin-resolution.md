# ADR-0001: local-first Douyin resolution and download

- Status: accepted
- Date/owners: 2026-08-26 / Fabushi product engineering

Context: mature open-source tools are Python-heavy or remote services; Fabushi already ships a Rust official-MiniApp CLI/MCP/WASM boundary. Sending an authenticated Douyin cookie to a remote parser creates avoidable privacy and account risk.

Decision: add a local-only official MiniApp runtime. It accepts explicit user-authorized URLs and an optional local cookie file, validates Douyin hosts, resolves known embedded data/API response shapes, ranks non-watermarked HTTPS candidates, downloads sequentially with retries/deduplication, and writes a redacted manifest. Marketplace metadata/package may expose UI and install information; local file operations stay in the desktop/CLI runtime.

Alternatives rejected: bundle `yt-dlp`/Python (size/toolchain), adopt `f2` wholesale (scope/dependency), or operate a remote resolver (cookie/privacy/SSRF). Consequence: smaller trusted boundary but ongoing parser maintenance. Rollout uses CI fixtures plus gated live smoke; rollback yanks the release/catalog entry.
