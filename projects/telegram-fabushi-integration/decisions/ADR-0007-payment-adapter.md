# ADR-0007 — PaymentIntent + Provider Adapter + Ledger

- **状态**：Accepted
- **日期**：2026-08-22
- **来源**：`../source/完整telegram融合进fabushi.txt`

## Context

隔离具体支付渠道，保证 webhook 幂等、账本一致和未来扩展。

## Decision

支付核心抽象订单、PaymentIntent、provider adapter、webhook、ledger、退款与对账；Mini App/Bot/Agent 只通过统一支付协议创建意图。

## Consequences

支付合规、渠道差异和虚拟商品规则需在实际 provider 接入时单独审查。

## Supersedes / Superseded by

无。
