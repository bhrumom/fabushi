# ADR-0004 — Local-First + Delta Sync

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

保证首屏速度、离线可读和网络恢复后的稳定体验。

## Decision

本地数据库作为客户端即时读取源，后台通过增量同步、sequence/cursor 和幂等机制保持一致。

## Consequences

同步算法必须专项覆盖重试、乱序、重复、多设备与 schema migration。

## Supersedes / Superseded by

无。
