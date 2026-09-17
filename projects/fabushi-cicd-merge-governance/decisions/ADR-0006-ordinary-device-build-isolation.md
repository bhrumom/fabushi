# ADR-0006 — Isolate builds from ordinary/persistent devices

- Status: accepted
- Date: 2026-09-17
- Project: FAB-P0003 / FCM
- Task: FCM-025

## Context

A persistent control/service host (`bhrum2`) reached 100% root-disk utilization. Repository work must not recreate large compiler, package, dependency or test caches on machines that also carry long-lived operational responsibilities. Existing wording said “no local builds/tests” but did not explicitly classify persistent VPS/MCP/service hosts as non-build surfaces or enumerate disk-growing operations.

## Decision

- Treat every long-lived workstation/VPS/server/service/MCP host as an ordinary device unless the user explicitly designates it as a disposable build runner for the task.
- Ordinary devices may inspect/edit source, orchestrate GitHub/APIs, operate services and deploy already-built bounded artifacts, but must not compile/build/package or create build-producing test artifacts.
- All compilation/package construction and materially disk-growing dependency/cache work runs on GitHub Actions or an explicitly designated disposable build runner.
- Disk cleanup on a persistent host is recovery only; it never authorizes restarting a local build.
- Deployment of prebuilt artifacts remains allowed, but staging must be bounded and rollback-safe.

## Consequences

- Slower network/Actions availability cannot be bypassed by building on `bhrum2` or another persistent host.
- Build failures are diagnosed from Actions logs and repaired source-side.
- Persistent devices keep predictable disk pressure and remain available for service/control responsibilities.
