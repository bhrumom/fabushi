# ADR-0015 — Developer-owned Commerce Catalog Provisioning

- Status: Accepted
- Date: 2026-09-11
- Project: FAB-P0001 / TFI
- Stage: M9 Payments

## Context

Fabushi 是承载多个第三方 Mini App 的平台。若官方 Mini App 通过内部 seed/admin 路径创建商品，而第三方开发者通过另一套 API 创建商品，目录、价格版本、商店同步和对账就会产生不可审计的双轨行为。用户明确要求官方商品也必须走第三方开发者路径，并需要支持批量创建、批量更新和 Google Play 对账。

## Decision

1. Developer Commerce API 是所有 Mini App 商品目录的唯一写入口；调用者必须通过 server-side developer/app authorization。
2. 批量 upsert 以 `mini_app_id + sku` 为稳定键；价格变化只追加新的 price revision，不覆盖历史支付事实。
3. `global-dharma` 只是官方开发者名下的普通 Mini App，使用同一批量 API、provider binding、audit 和 reconciliation 流程。
4. 历史官方商品采用 forward-only adoption migration：保留 product/price/order/entitlement ID 和历史事实，只补 `catalog_source` 与 adoption audit，不重新插入商品。
5. Google Play 同步由 Fabushi server/control plane 取得一次授权后批量执行，定时 reconcile 发现缺失/过期绑定；Apple/Google 外部资格未就绪时保持 pending/fail-closed。
6. Web/Desktop/Platform proxy/UI 只调用开发者批量 API；不再保留 admin product create/update 路由。

## Open-source-first survey and provenance

在实现前审阅了成熟开源目录架构：

- [Saleor](https://github.com/saleor/saleor)（BSD-3-Clause）：API-only、GraphQL、channel/currency/catalog projection 和 webhook/app 扩展边界；吸收 API-first 与多渠道投影原则，不引入 Django/GraphQL runtime。
- [Vendure](https://github.com/vendurehq/vendure)（GPLv3 / commercial dual licensing）：稳定 plugin contract、channel price 与 e2e harness；因 GPL/运行时与 Rust/Cloudflare 边界不匹配而拒绝依赖，只借鉴扩展边界和测试分层。
- [Medusa](https://github.com/medusajs/medusa)（open-core，核心 MIT）：模块化 product/price/order primitives；因 Node/数据库/账本模型与现有 Rust/D1 canonical Pay 不同而不引入。

没有复制上述仓库代码或引入其依赖。Fabushi 保留自己的 owner-scoped authorization、D1 schema、price revision、provider binding、audit 和唯一 Rust Pay ledger；开源项目只作为架构交叉检查，许可证义务不随实现代码进入产品。

## Consequences

### Positive

- 官方与第三方开发者拥有完全一致的商品生命周期和审计路径；
- 批量价格变更不会重建商品或破坏历史订单；
- Google Play 同步与对账可由控制面自动化，客户端不持有商店凭据；
- 支付价格仍来自服务端 catalog，并继续进入同一本 Fabushi Pay ledger。

### Costs and constraints

- Developer API 与控制面必须持续保持授权、限额、幂等和审计；
- Google/Apple/Stripe/支付宝生产资格仍需外部批准和凭据；
- adoption migration 是只前进不回滚的历史事实修复，回滚只能回滚应用代码，不能删除历史订单/权益。
