# M9-GLOBAL-DHARMA-003 — 全球法布施本地转经轮付费能力

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Stage**: `M9 支付 / Monetization`
- **Status**: `IMPLEMENTING`
- **Branch**: `feat/m9-global-dharma-monetization`
- **Depends on**: `M9-MONETIZATION-002` / PR #2132
- **Source**: `source/2026-08-25-global-dharma-paid-prayer-wheel.md`

## Objective

将官方全球法布施小程序的 `local.prayer-wheel.start` 变成真正由 canonical Entitlement 控制的付费能力：月付 CNY 30，买断 CNY 1080。支付、订阅、退款和授权均复用 Rust Fabushi Pay / PLATFORM_DB。

## Acceptance criteria

1. 服务端 Trusted Product Catalog 注册两个官方商品，客户端不得提交金额。
2. 月付金额为 3000 CNY minor units，买断为 108000 CNY minor units。
3. 两种商品都授予 `local.prayer-wheel.start`；月付拥有有效到期时间，买断无到期时间。
4. capability access gate 在 host request 暴露/执行前强制检查，不以隐藏按钮代替安全边界。
5. 无 entitlement / 已过期 / revoked 状态均拒绝启动并返回可购买 SKU。
6. 有效月付或 lifetime entitlement 允许继续宿主审批流程。
7. 全球发送等免费能力不受影响。
8. Web/desktop checkout 通过统一 Monetization facade -> canonical Rust Pay web provider；Apple/Google 使用 canonical rails，真实 storefront product 未配置时不得假装可用。
9. 全部单元/contract/E2E 门禁通过，PR 经 protected main 合并并完成 exact-main delivery evidence。

## External dependencies

- Apple App Store / Google Play 的真实商品 ID 和商店后台商品创建属于外部 storefront 配置；代码只预留 canonical provider refs，未完成真实商店配置时对应 rail 应保持不可生产使用。
- Web provider checkout 需要生产 `FABUSHI_PAY_CHECKOUT_URL` 与 provider webhook 配置。

## Evidence

Pending implementation/CI/PR/main/deployment evidence. Do not mark complete before those facts exist.
