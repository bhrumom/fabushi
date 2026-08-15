# Grok Bot 0.20.0 canonical production snapshot

This directory is the canonical latest-product reference for the Fabushi desktop fusion.

## Provenance

Recovered on 2026-08-16 from the official Grok Bot stable update service:

- version: `0.20.0`
- release SHA: `ca2c2b6f79b6130a4822d8189711b0f79f9d4661`
- platform: `darwin-arm64`
- source archive: official `downloads.cursor.com/grokbot/stable/.../Cursor-darwin-arm64.zip`

The release contains no JavaScript source maps. Therefore `canonical/` preserves the shipped production code byte-for-byte for the application-owned runtime surfaces that matter to parity:

- renderer HTML and all renderer JS/CSS/assets
- Electron main
- Electron preload surfaces
- node agent coordinator
- local execution daemon
- Grok/Sand host and workers
- Electron dev controls
- package metadata

Native/dependency payloads under `dist/deps` and native binaries are intentionally not vendored here; they are third-party/build artifacts rather than the Grok product source we need to fuse.

## Fusion strategy

The 0.20.0 snapshot is the behavioral/UI source of truth. Where an older Grok release still contains source maps, those maps are used only to recover readable TS/TSX module structure; every recovered module must be reconciled against this 0.20.0 production snapshot before becoming canonical Fabushi source.

The target is not a compatibility wrapper around the old application. The target is source-level fusion: original Grok UI/state machines in Fabushi, with Sand/Cursor backend edges replaced by Mahayana Feature Host adapters.
