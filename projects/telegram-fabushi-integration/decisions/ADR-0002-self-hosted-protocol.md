# ADR-0002 — 自主协议与自建服务

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

项目目标是形成 Fabushi 自有通信平台，而不是 Telegram 第三方客户端。

## Decision

核心通信使用 Fabushi 自有版本化协议与自建服务，不依赖 Telegram API、Bot API 或 MTProto 网络。

## Consequences

Fabushi 需要自行承担网关、同步、媒体、推送、运维与协议兼容成本。

## Supersedes / Superseded by

无。
