# Fabushi Pay / Monetization Platform

- **项目**：Fabushi Telegram 全量融合
- **Project ID**：`FAB-P0001`
- **文档 ID**：DOC-11
- **版本**：v1.2
- **状态**：IMPLEMENTATION_ACTIVE
- **基线日期**：2026-08-22
- **扩展日期**：2026-08-25

目标：Mini App、Bot、Agent、聊天内商品、订阅、广告和开发者收益统一进入 Fabushi Monetization Platform；支付只是收入来源之一。

## 1. 唯一资金真相

生产资金移动的唯一权威是：

- `third_party/mahayana/mahayana-rs/mahayana-pay-worker`
- `PLATFORM_DB`
- `wallet_accounts`
- `journal_entries`
- `journal_lines`
- `wallet_balances`

任何 Web/桌面/移动/MiniApp 业务层只能创建 PaymentIntent、提交 provider 事实、读取 entitlement/Revenue Event/余额投影，禁止再维护第二套可写余额或复式账本。

`#2131` 第一轮建立的 legacy-DB 平行账本原型已经在 M9 canonical convergence 中退役；其有价值的不变量被迁移到 canonical Rust Pay + Monetization control plane。

## 2. 统一领域模型

- Developer / Merchant / DeveloperCompliance
- Product / Price
- PaymentIntent / Order / PaymentAttempt / Provider
- Subscription
- Entitlement
- RevenueEvent
- Versioned SplitRule
- Canonical Ledger Journal / Lines
- Developer Pending / Available
- SettlementRelease / PayoutAccount / PayoutRequest / Payout
- Refund / Chargeback reversal
- Advertiser / Campaign / Placement / Verified Ad Event
- ProviderEvent / Reconciliation

## 3. 支付与资金流

```text
MiniApp/Bot/Agent
    |
    v
Monetization Checkout Facade
    |
    v
Canonical Rust Fabushi Pay
    |
    +--> Credits
    +--> Apple IAP
    +--> Google Play Billing
    +--> Web Provider
    +--> Merchant Provider
    |
    v
PaymentIntent -> provider verification/webhook
    |
    v
Canonical balanced journal
    |
    +--> platform payment revenue
    +--> developer pending
    |
    v
Order + Entitlement
    |
    v
Revenue Event projection
```

所有金额都使用最小货币单位整数。实际资金 journal 每币种必须净额为 0；Revenue Event 是商业分析/分账追踪投影，不是第二本账。

## 4. Provider adapters

Canonical Rust Pay 当前拥有：

- `credits`
- `apple_in_app_purchase`
- `google_play_billing`
- `web_provider`
- `merchant_provider`

Apple/Google 服务端验证与 provider transaction binding 在 Rust Pay 完成；标准化 web/merchant webhook 负责 `paymentSucceeded`、refund、chargeback、payout 等事件。

Legacy Alipay API 仅保留 compatibility；不得继续扩展第二套商业逻辑。新的支付产品必须进入 canonical PaymentIntent/provider rail。地区 PSP 可通过 web/merchant provider adapter 接入。

## 5. Revenue Event

Revenue Event 标准化 payment、subscription、advertising、refund、chargeback、payout、tip/API usage 等商业事件。

关键原则：

- `(source_kind, source_id)` 唯一；
- payment Revenue Event 只投影 canonical payment 结果，不重新记账；
- refund/chargeback 保留原事件并创建 reversal Revenue Event；
- fully refunded 原收入可标记 `reversed`，历史仍保留；
- reconciliation 可以补漏投影，但不得改造资金余额。

## 6. Versioned Split Rule

规则按 `scope_type + scope_id + revenue_source + version + effective window` 管理。

支持 scope：platform、miniapp、product、ad placement。每条 two-party 规则必须满足：

```text
platformBps + developerBps = 10000
```

规则不可回写历史版本；新规则通过新的 version/effective_from 生效。所有分配使用整数最小货币单位，余数确定性归属，确保逐分守恒。

## 7. Subscription 与 Entitlement

`Payment != Subscription != Entitlement`。

- Payment：证明一笔资金事实。
- Subscription：管理 active/past_due/paused/cancelled/expired/refunded 生命周期、周期和 cancel-at-period-end。
- Entitlement：唯一产品功能访问权限源。

成功 subscription PaymentIntent 建立订阅投影；Apple/Google/web provider 的 normalized lifecycle event 更新订阅周期，并同步 entitlement expiry/revocation。Reconciliation 会回收已过期但仍 active 的订阅/权益。

## 8. Advertising Alliance

V1 广告控制面包含：

- Campaign
- Placement
- CPM / CPC / CPA / Rewarded billing
- server-authoritative bid/budget
- verified ad event
- idempotency key
- session/actor hash
- canonical ad revenue journal
- Revenue Event
- developer pending revenue

客户端不能提交广告单价。只有受信事件生产者通过 secret-authenticated endpoint 产生 `verified` billable event 后才允许入账。广告分成可由 placement 默认 share 或 effective-dated Split Rule 覆盖。

广告竞价、素材审核、品牌安全、受众同意与反作弊模型可以继续演进，但不得绕过 verified-event → canonical journal 边界。

## 9. Developer revenue / settlement / payout

开发者余额不存 mutable balance 字段，而从 canonical ledger 投影：

```text
Payment/Ad Revenue -> developer pending
settlement release -> developer available
payout reservation -> payout clearing
provider result -> paid / failed(reversal)
```

Payout 请求必须同时满足：

- developer profile 存在；
- KYC/KYB compliance = `verified`；
- `payout_enabled = true`；
- canonical payout account = `active`；
- canonical available balance 足够。

Public developer API 只能申请 payout；实际资金保留/提交仍由 canonical Rust Pay 执行。KYC 身份材料不保存在 Fabushi 表中，仅保留外部 provider reference 和状态。

## 10. Refund / Chargeback

退款和拒付由 Rust Pay 创建反向 journal：

- 按原平台费率退回 platform revenue；
- 优先冲 developer pending，再冲 released/available；
- 退款总额不能超过剩余可退款额；
- webhook/event id 幂等；
- 原 capture journal 永远保留。

Monetization reconciliation 为成功退款补独立 reversal Revenue Event，便于开发者报表与审计。

## 11. Reconciliation

`POST /api/admin/monetization/reconcile` 负责：

- 补成功 PaymentIntent 缺失的 Revenue Event；
- 补成功退款 reversal Revenue Event；
- fully refunded 原收入标记 reversed；
- 过期 subscription/entitlement 回收；
- payout request 与 canonical payout 状态收敛；
- 检查 successful payment without journal；
- 检查 orphan payment Revenue Event；
- 检查 ad Revenue Event without journal；
- 检查 posted journal 每币种是否不平衡。

验收态要求 anomaly 为 0。

## 12. API surface

User/developer：

- `POST /api/monetization/checkout`
- `GET /api/monetization/payment?paymentId=...`
- `GET /api/monetization/entitlements`
- `GET /api/monetization/subscriptions`
- `POST /api/monetization/developer/register`
- `GET /api/monetization/developer/summary`
- `POST /api/monetization/payouts/request`

Trusted internal producer：

- `POST /api/monetization/providers/subscription-event`
- `POST /api/monetization/ads/events`

Admin：

- split rules
- ad campaigns / placements
- developer compliance
- canonical payout account bridge
- payout submit bridge
- settlement release bridge
- reconciliation

## 13. 实现位置

Canonical financial core：

- `third_party/mahayana/mahayana-rs/mahayana-pay-worker/`
- `third_party/mahayana/mahayana-rs/mahayana-platform-worker/src/payment_api.rs`
- `.../migrations/0001_platform.sql`
- `.../migrations/0007_fabushi_pay.sql`

Unified monetization control plane：

- `.../migrations/0008_monetization_platform.sql`
- `fabushi/web/src/services/monetization-platform.js`
- `fabushi/web/src/handlers/monetization-platform.js`
- `fabushi/web/src/handlers/monetization-reconciliation.js`
- `fabushi/web/src/routes/monetization-routes.js`
- `fabushi/web/tests/monetization-platform.test.js`
- `../management/tasks/M9-MONETIZATION-002-canonical-convergence.md`

## 14. 合规边界

V1 不把 Fabushi 设计成自行托管客户资金的支付机构。实际法币收单、KYC/KYB 与 payout 应交给有资质的 PSP/marketplace provider。通用、可转让、可提现的用户储值余额不属于 V1；若未来启用，必须先完成目标司法辖区的支付/电子货币监管评估。

重要原则：商业化系统不与聊天 UI 直接耦合；Chat/MiniApp/Bot/Agent 只消费 Payment/Subscription/Entitlement/Revenue/Payout 领域事件。
