# 2026-08-24 — Grok Bot 0.18 reconstructed repository fusion

## Original request

用户指定 `https://github.com/bhrum/grok-bot-0.18-reconstructed`，要求把其中代码完全融合到 Fabushi，并一比一实现可观察效果。

## Pinned source

- Repository: `bhrum/grok-bot-0.18-reconstructed`
- Commit: `a9f633e09d49a85829b8236331b9e21f7e612634`
- Tree: `b68f24972427952c4934e4364736fec62661044f`
- Declared product baseline: public Grok Bot `0.18.0` macOS arm64 artifact

## Rights and implementation boundary

The source repository's `NOTICE.md` and `PROVENANCE.md` explicitly state that no upstream source-code license is asserted or granted. It also preserves original installers through Git LFS and packages a checksum-pinned shipped renderer. Fabushi therefore must not copy the repository wholesale, import the installers, or redistribute the compiled renderer.

The accepted interpretation is complete observable-capability fusion through clean-room implementation: every path and capability receives a durable classification and reuse decision; behaviors selected for retention are independently implemented in Fabushi-owned Electron/Rust/Mahayana modules and verified against objective contracts, screenshots, videos, traces, and packaged user journeys.

## Notable delta beyond the existing GBF baseline

- Cursor / Claude Code / Codex / OpenRouter inference Router and settings surface.
- Routed MCP tool execution and transcript continuity across provider selection.
- Local provider usage counters.
- Optional loopback-only local Docker sandbox lifecycle.
- Reconstructed settings presentation and provider readiness diagnostics.

These features are additions to the existing GBF roadmap, not permission to introduce a second Grok/Node runtime.
