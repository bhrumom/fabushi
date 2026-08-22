# ADR-0002: Electron / Mahayana Boundary

Status: Accepted — 2026-08-22

## Decision
Renderer 只负责 UI；preload 只暴露最小版本化 contract；Electron main 负责系统生命周期和授权编排；Agent 核心、tool policy 和跨平台业务逻辑优先进入 Mahayana/Rust 运行时或明确的 host adapter。

## Consequences
禁止 renderer 任意 shell/通用 IPC，减少 JS 主进程业务重复和权限面。
