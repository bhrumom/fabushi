# Fabushi Pay Rust 基础设施

更新日期：2026-08-21

## 目标

Fabushi Pay 借鉴 Telegram 公开支付协议与客户端可观察行为，但不复制 Telegram GPL 客户端实现，也不依赖 Telegram 的闭源支付后台。支付核心由 Fabushi 使用 Rust 独立实现，并作为 Mahayana 平台能力供 Electron、iOS、Android 与 Mini App Host 共用。

Telegram 参考点只用于行为与协议研究：Invoice / Payment Form、Mini App open invoice、Stars 的服务端权威余额、支付表单幂等、支付成功后再发货、退款和开发者 revenue 的分层。Telegram 的中央 Stars ledger、风控、清结算和提现服务并未开源，因此这些能力必须由 Fabushi 自己设计。

## 信任边界

Mini App 是不可信执行环境。它只能提交 `sku + idempotencyKey`，不能提交或覆盖价格、币种、开发者、平台费率、支付 Provider 或结算账户。

```text
Mini App
  |  pay.createIntent(sku, idempotencyKey)
  v
Trusted Host / Product Catalog
  |  resolves user + miniApp + developer + price + fee + rail
  v
Fabushi Pay Core (Rust)
  |  PaymentIntent + balanced ledger
  +--> Apple IAP adapter
  +--> Google Play Billing adapter
  +--> Web payment provider adapter
  +--> Fabushi Credits ledger
```

Provider secret、银行卡资料、Store receipt signing key 与 webhook secret 永远不能进入 Mini App WebView/WASM/plugin memory。

## Mini App API

当前桥接方法：

- `pay.createIntent`：从受信任商品目录创建支付意图。
- `pay.openCheckout`：请求宿主打开原生/平台收银台。
- `pay.getStatus`：读取服务器权威支付状态。

三者都要求现有 `commerce.purchase` 权限。退款、结算、提现不开放给 Mini App，只允许受信任开发者后台或平台服务调用。

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

支付成功的 Provider reference 支持幂等重放：相同 reference 再次到达不重复记账，不同 reference 不能覆盖已经成功的支付。

## 双重记账

每个 Journal Entry 按币种严格平衡，任一币种所有 line 的 signed minor units 必须合计为 0。

示例：用户支付 1000 FBC、平台费 15%。

```text
provider-clearing:FBC      -1000
platform-revenue            +150
developer-pending:dev-1      +850
                              ----
                                 0
```

等待风险期结束后：

```text
developer-pending:dev-1      -850
developer-available:dev-1    +850
                              ----
                                 0
```

退款发生在结算前时冲减 pending；结算后发生退款时冲减 available，避免伪造 pending 负余额。每笔支付记录已经释放的 developer net，因此不能通过更换 idempotency key 重复释放收入。

## 用户 Credits 与开发者收入隔离

Fabushi Credits (`FBC`) 是用户消费权益，不等于开发者可提现余额。

```text
User Credits
  -> consume digital product
  -> Developer Pending Revenue
  -> risk/return window
  -> Developer Available Revenue
  -> regulated payout adapter
```

这与“把用户 Credits 原样转给开发者”不同。开发者收入由销售事件和结算规则产生，方便后续接 Stripe Connect、银行/当地持牌支付服务商或其他合法结算渠道。

## 已实现

- Rust `PayEngine` 与强类型 Payment Intent。
- FBC / 外部支付 rail 抽象。
- 双重记账平衡校验。
- create payment 幂等。
- Provider success replay 防双记账。
- Pending / Available revenue。
- 部分退款 / 全额退款基础状态。
- 结算后退款的 available 冲减。
- 结算防重复释放。
- Mini App `pay.createIntent/openCheckout/getStatus` 权限门禁。
- Mini App 协议拒绝客户端注入 amount/currency。

## 下一阶段

1. 持久化：把 PaymentIntent、idempotency、journal 与 provider event 写入服务端 ACID 数据库，并以数据库事务替代当前内存引擎容器。
2. Catalog：`mini_app_id + sku` 服务端商品目录，绑定 developer、product kind、价格、地区与允许的 rail。
3. Credits：用户充值 ledger、消费扣账、余额快照与并发原子扣减。
4. Provider adapters：Apple StoreKit/App Store Server API、Google Play Billing/Developer API、Web/merchant provider。
5. Webhook inbox：签名验证、去重、顺序无关事件处理、重放与死信。
6. Revenue policy：风险等待期、退款储备、chargeback、税费和平台费拆分。
7. Payout：开发者 KYC/KYB、可用余额、提现请求、出款状态、失败回滚和对账。
8. Reconciliation：provider statement / store financial report 与内部 ledger 日终对账。
9. Risk：速率限制、设备/账户风险、异常退款、盗刷与商户风控。
10. E2E：Electron/iOS/Android 原生收银台与 Mini App invoice closed/status reconciliation。

## 许可证边界

Telegram Android/iOS/Desktop/Web 客户端中的 GPL 实现只用于可观察行为、交互与测试参考。Fabushi 支付 Rust 实现基于公开协议、官方文档、Boost 许可的 TDLib/Bot API 合约以及独立设计完成，不逐行翻译或复制 GPL 客户端源代码。
