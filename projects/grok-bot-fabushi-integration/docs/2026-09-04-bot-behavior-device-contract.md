# GBF Bot behavior + same-account capability contract — 2026-09-04

- Project ID: `FAB-P0004`
- Program: `FAB-ARCH-P0-20260904`
- Status: architecture baseline; implementation unverified

## Group behavior

Privacy-mode Bot is invoked only by directed signals: explicit mention, reply-to-Bot, registered command/slash, or another explicitly configured directed trigger. Ambient group traffic does not invoke or expose content to it. A non-privacy mode requires explicit configuration/policy.

A Bot uses the same MSR durable session across direct/group/topic contexts. Streaming progress, tool call, approval, tool result/error and final answer are structured states with invocation correlation and visible provenance; UX may study observable Grok behavior but implementation is clean-room.

## Same-account devices and MiniApps

Reuse GBF-409 device presence/pair/control separation and GBF-411 Web/App MCP semantic surfaces. Bots discover only capabilities that MSR-211 admits. Login alone never grants control. Installed MiniApps expose validated WebMCP/MCP/CLI tools through the same capability plane; third-party apps without semantic surface use approved Computer Use fallback.

## Security/test/release

Negative tests must prove ambient-message ignore, unauthorized device control, stale target/generation, revoked pairing, uninstalled MiniApp, denied approval and redaction. Heavy verification only via GitHub Actions. Test-release video must show both successful directed invocation and a non-invocation privacy case, plus approved device/MiniApp action and denied control. Formal release follows protected-main exact-main packaged E2E.