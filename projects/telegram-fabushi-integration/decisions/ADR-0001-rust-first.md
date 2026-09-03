# ADR-0001 — Rust First 核心

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

避免 Electron/Swift/Kotlin 三套业务状态机，获得跨端一致性、性能与可测试性。

## Decision

网络、协议、加密、消息状态机、本地存储、同步、媒体、搜索与队列使用 Rust；UI 通过统一 SDK/binding 调用。

## Consequences

需要维护 N-API/UniFFI/JNI 等边界，并严格限制客户端绕过 Core。

## Supersedes / Superseded by

无。
