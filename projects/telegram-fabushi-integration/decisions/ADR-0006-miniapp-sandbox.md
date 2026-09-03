# ADR-0006 — Mini App 权限与沙箱

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

Mini App 同时接触会话、Bot/Agent、文件、系统和支付，需要默认隔离。

## Decision

Mini App 通过 manifest、signed init data、显式权限 bridge 和可撤销授权访问 Fabushi 能力。

## Consequences

SDK 兼容与权限模型将成为平台长期公共 API。

## Supersedes / Superseded by

无。
