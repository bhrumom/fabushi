# Fabushi Pay Rust 支付基础设施

更新日期：2026-08-22

## 目标与许可证边界

Fabushi Pay 是 Fabushi / Mahayana 自己的支付基础设施。设计阶段研究 Telegram 公开的 Invoice、Payment Form、Mini App、Stars、退款与开发者收入交互，但不复制 Telegram GPL 客户端实现，也不依赖 Telegram 的闭源 Stars ledger、风控、清结算或提现后台。

Telegram 客户端只作为公开协议和可观察行为参考；Fabushi Pay 的 Rust 状态机、账本、Cloudflare Worker、Mini App 合约、StoreKit / Google Play 接线和部署流程均为独立实现。

## 生产拓扑

```text
Mini App / Electron / iOS / Android
        |
        | sku + idempotencyKey
        v
https://pay.ombhrum.com
Fabushi Pay Rust Worker
        |
        +-- Trusted Product Catalog
        +-- Payment Intent / Idempotency
        +-- Apple App Store Server API
        +-- Google Play Developer API
        +-- Web / Merchant Provider Webhook Inbox
        +-- Refund / Dispute
        +-- Settlement / Payout
        |
        v
Shared Mahayana PLATFORM_DB (Cloudflare D1)
        |
        +-- wallet_accounts / wallet_balances
        +-- journal_entries / journal_lines
        +-- products / prices / orders / entitlements
        +-- payment_intents / webhook inbox / refunds / disputes
        +-- developer pending / available / payout records
```

支付服务是独立 Cloudflare Worker `fabushi-pay-prod`，与现有 Mahayana 平台共享同一权威 D1 总账，避免在旧的大型 Worker 中复制账务数据。

## Mini App 信任边界

Mini App 属于不可信执行环境。`pay.createIntent` 只允许提交：

```json
{
  "sku": "creator.pro.month",
  "idempotencyKey": "client-generated-stable-key"
}
```

价格、币种、开发者、商品类型、平台费率、允许的支付 rail、Apple/Google product id 均由服务端 Trusted Product Catalog 决定。客户端注入 `amount` / `currency` 等字段会被协议拒绝。

Mini App Host 暴露：

- `pay.createIntent`
- `pay.openCheckout`
- `pay.getStatus`

全部要求 `commerce.purchase`。Mini App 不获得退款、结算、提现、Provider secret 或平台管理权限。

## HTTP API

用户接口：

- `POST /v1/miniapps/:mini_app_id/pay/intents`
- `GET /v1/pay/intents/:payment_id`
- `POST /v1/pay/intents/:payment_id/checkout`
- `POST /v1/pay/intents/:payment_id/credits/confirm`
- `POST /v1/pay/intents/:payment_id/apple/verify`
- `POST /v1/pay/intents/:payment_id/google/verify`

Provider 接口：

- `POST /v1/pay/providers/:provider/webhook`

平台管理接口（`FABUSHI_PAY_ADMIN_TOKEN`）：

- `POST /v1/pay/admin/products`
- `POST /v1/pay/admin/settlements/release`
- `POST /v1/pay/admin/payout-accounts`
- `POST /v1/pay/admin/payouts`
- `GET /v1/pay/admin/developers/:developer_id/balance/:currency`

健康检查：`GET /health`。

## Payment Intent 状态机

```text
Created
  +--> RequiresAction --> Processing --> Succeeded
  |          |               |
  |          +--> Failed     +--> Failed
  |          +--> Cancelled
  +--> Processing
  +--> Failed
  +--> Cancelled

Succeeded --> PartiallyRefunded --> Refunded
          \-----------------------> Refunded
```

相同 Provider reference 重放不会重复记账；不同 reference 不能覆盖已成功付款。创建、退款、结算、提现都具有独立幂等边界。

## 双重记账

所有金额使用整数 minor units。每个已 posted Journal Entry 按币种必须严格平衡。

FBC 消费 1000，平台费 15%：

```text
user:FBC                         -1000
developer-pending:developer:FBC   +850
platform:payment-revenue:FBC      +150
                                  ----
                                     0
```

外部 Provider 收款使用 Provider Clearing 作为 source：

```text
provider-clearing:apple:USD       -1000
developer-pending:developer:USD    +850
platform:payment-revenue:USD       +150
                                  ----
                                     0
```

风险等待期结束后：

```text
developer-pending                 -850
developer-available               +850
                                  ----
                                     0
```

退款发生在结算前优先冲减 Pending；已经释放后冲减 Available。分次退款使用累计差额法计算平台费退款，完整退款最终严格冲回原始手续费。

## D1 持久化

`0007_fabushi_pay.sql` 增加：

- `payment_product_config`
- `payment_intents`
- `payment_webhook_events`
- `fabushi_payment_refunds`
- `payment_disputes`
- `developer_payout_accounts`
- `developer_settlement_releases`
- `developer_payouts`

同时复用 0001 中的 `wallet_accounts`、`wallet_balances`、`journal_entries`、`journal_lines`、`products`、`prices`、`orders`、`payment_attempts`、`entitlements`、`audit_events`。

支付成功、退款、结算和提现预留均通过 D1 batch 形成平衡分录；业务状态只有在对应 Journal Entry 成功 posted 后才推进。

## Apple

iOS 使用 StoreKit 2。原生客户端：

1. 从 Fabushi Pay 获得 Payment Intent 和 Apple product id。
2. 以 Payment Intent UUID 作为 `appAccountToken` 发起购买。
3. 只接受本地 verified transaction。
4. 把 transaction id 发给 Fabushi Pay。
5. Rust Worker 使用 App Store Server API 再验证 bundle id、product id、transaction id、revocation 状态以及 `appAccountToken == paymentId`。
6. 服务端成功记账后客户端才 `finish()` transaction。

这防止一个真实 App Store transaction 被另一个 Fabushi 账号抢先认领。

## Google Play

Android 使用 Google Play Billing 9.1.0。原生客户端：

1. 查询当前 ProductDetails / subscription offer。
2. 以 Payment Intent id 作为 `obfuscatedAccountId` 发起 Billing Flow。
3. Purchase 必须为 `PURCHASED`。
4. purchase token 发给 Fabushi Pay。
5. Rust Worker 使用 Android Publisher API 验证商品、购买状态、order id，并要求 `obfuscatedExternalAccountId == paymentId`。
6. Fabushi Pay 成功记账后，客户端才 acknowledge；消耗型商品才 consume。

## Web / Merchant Provider

Web 与 Merchant Provider 不直接信任浏览器回调。Provider gateway 向：

`POST /v1/pay/providers/:provider/webhook`

发送标准化事件并使用 `FABUSHI_PAY_WEBHOOK_SECRET` 鉴权。Webhook Inbox 以 `(provider, event_id)` 去重并保存 payload SHA-256：

- 同 event id + 同 payload：幂等；
- 同 event id + 不同 payload：409 拒绝；
- 已 rejected 的同 payload 事件可重试；
- 已 processed / processing 事件不会重复入账。

标准事件覆盖 payment success/failure/cancel、refund、chargeback open/won/lost、payout paid/failed。

## 开发者 Revenue 与提现

销售收入先进入 `developer-pending`；超过 hold period 后根据 reserve bps 释放到 `developer-available`。同一 payment 可以在降低 reserve 后分阶段继续释放，但每次 release 都有唯一 idempotency key。

提现先把 Available 原子预留到 payout-clearing；Provider 出款失败则生成反向 Journal Entry 回补 Available。Mini App 永远不能直接调用这些接口。

KYC/KYB、税务、银行卡/当地支付机构开户属于真实资金出款 Provider 的外部合规流程，不能由客户端代码绕过；仓库只保存 Provider 的 opaque external account reference，不保存银行卡敏感资料。

## 原生客户端

- iOS：`mobile/ios/Fabushi/FabushiPayStoreKit.swift`
- Android：`mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiPayBilling.kt`
- Android Billing dependency：`com.android.billingclient:billing-ktx:9.1.0`

Electron / Mini App 使用同一 Payment Intent / Checkout contract；只有具体平台商店弹窗由原生层处理。

## 生产配置

`fabushi-pay-prod` 必需：

- `ACCESS_TOKEN_PUBLIC_KEY_PEM`
- `APPLE_ISSUER_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_PRIVATE_KEY`

生产 vars：

- `APPLE_BUNDLE_ID = com.ombhrum.fabushi`
- `GOOGLE_PLAY_PACKAGE_NAME = com.ombhrum.fabushi`

按启用能力可配置：

- `FABUSHI_PAY_ADMIN_TOKEN`
- `FABUSHI_PAY_WEBHOOK_SECRET`
- `FABUSHI_PAY_CHECKOUT_URL`

GitHub 部署 workflow 可从现有 App Store Connect 与 Google Play release secrets 派生对应服务端凭证；secret 不写入仓库。

## CI/CD 与验收

PR 的 canonical `CI` Worker contract 会：

- Rust host tests
- Clippy `-D warnings`
- wasm32-unknown-unknown 实际编译
- rustfmt
- SQLite 顺序应用 0001 + 0007 migration
- 支付边界/secret-pattern 静态检查

原生移动端继续走仓库现有 iOS SwiftUI 与 Android Compose simulated-user gate。

合并 main 后，`Fabushi Pay production deploy` 只在主 CI success 后：

1. checkout CI 已验证的精确 SHA；
2. 再次编译 payment Worker；
3. 对 production `PLATFORM_DB` 应用 migration；
4. 同步 Cloudflare Worker secrets；
5. 部署 `fabushi-pay-prod`；
6. smoke `https://pay.ombhrum.com/health`。

如果外部商店密钥或 Access Token 公钥缺失，部署会 fail closed，不会发布半配置的支付服务。
