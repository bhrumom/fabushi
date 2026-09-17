# 2026-09-17 — Ordinary-device no-build / disk-safety requirement

## Original user requirement

> 在agent.md里面要求不能在普通设备里面进行构建消耗空间的操作，避免再出现bhrum2没有空间的问题

## Normalized requirement

1. Ordinary/persistent machines are control/edit/deployment surfaces, not build surfaces. This includes developer computers, long-lived VPS/server hosts, service/MCP hosts, and specifically persistent hosts such as `bhrum2`.
2. Compilation, package construction, build-producing tests, dependency/cache warming, browser/E2E dependency installation, Docker image construction, and other materially disk-consuming build operations must run on GitHub Actions or another explicitly designated disposable build runner.
3. Ordinary devices may perform low-footprint repository inspection/edit/orchestration, service operations, logs/health checks, and bounded deployment of already-built immutable artifacts.
4. Low disk space must fail closed: free-space recovery is for service health, not permission to resume local builds or repopulate caches.
5. Persistent-host deployment staging must be bounded and rollback-safe, with no deletion of service/database/source data to make room for builds.
6. This is repository-wide Agent governance and strengthens the existing no-local-build/test rule; it does not weaken the current zero-test prerelease / MCP-only formal-validation policy.

## Acceptance intent

- Root `AGENTS.md` contains an explicit ordinary-device no-build rule and names persistent VPS/MCP hosts such as `bhrum2` as covered.
- The rule enumerates prohibited build/cache classes and allowed low-footprint control-plane work.
- The rule directs all build/package work to GitHub Actions or an explicitly designated disposable runner and forbids using cleanup as justification to resume a persistent-host build.
- FCM project records include the disk-exhaustion risk, decision, task, evidence pointer, status and traceability.
- Protected-main readback confirms the policy after merge.
