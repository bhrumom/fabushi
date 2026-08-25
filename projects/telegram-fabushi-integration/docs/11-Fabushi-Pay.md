# Fabushi Pay / Monetization Platform

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-11
- **版本**：v1.1
- **状态**：ACTIVE_DESIGN
- **基线日期**：2026-08-22
- **扩展日期**：2026-08-25
- **源计划**：`../source/完整telegram融合进fabushi.txt`

目标：Mini App、Bot、Agent、聊天内商品、订阅和广告统一走 Fabushi Monetization Platform；支付只是收入来源之一。

## 统一领域模型

- Merchant / Developer
- Product / Price
- Order / PaymentIntent / PaymentMethod / Provider
- Subscription
- Entitlement
- RevenueEvent
- Versioned SplitRule
- Ledger Journal / Ledger Entry
- Developer Balance: Pending / Available / Reserved / Paid
- Settlement / Payout
- Refund / Chargeback reversal
- Ad Placement / Ad Event
- WebhookEvent

## 总体资金流

```text
Payment / Subscription / Verified Ad Event / Future Revenue Source
                         |
                         v
                   Revenue Event
                         |
                 Versioned Split Rule
                         |
                         v
              Immutable Double-entry Ledger
                         |
                         v
        Pending -> Available -> Reserved -> Paid
                         |
                         v
                    PSP Payout
```

所有金额使用最小货币单位整数（fen/cents），禁止用浮点数进行账务计算。每个 journal 必须满足 `total_debits_minor == total_credits_minor`，数据库与领域服务同时保护该不变量。

## Revenue Event

Revenue Event 是广告、支付、订阅等商业化来源进入账本的唯一标准入口。最少包含：

- event id + idempotency key
- source/source id
- scope type/scope id
- gross amount minor + currency
- customer/developer/miniapp/bot attribution
- occurred at + metadata

Provider webhook 重试、广告事件重试或网络重复投递必须复用同一个 idempotency key，不得重复形成收入。

## 分账

分账规则按 `scope + revenue source + version + effective window` 版本化。每个规则严格等于 `10000 bps`，历史事件固定使用事件发生时对应的规则版本。最小货币单位不能整除时采用确定性余数分配，保证逐分守恒。

示例：

```text
100 CNY gross
platform 20% + developer 75% + affiliate 5%
```

未来支付处理费、税费、渠道成本应通过明确 ledger account / split component 表达，不允许通过修改历史余额模拟。

## 订阅与权益

`Payment != Entitlement`。StoreKit、Play Billing、支付宝、Stripe、兑换码、管理员赠送最终都写入独立 Entitlement 模型，客户端只根据 Entitlement 判断是否解锁功能。订阅负责生命周期，支付负责资金确认，权益负责产品访问能力。

## 广告

广告事件先进入 `monetization_ad_events` staging 层。只有经过验证/反作弊并成为 billable event 后，才能转换为 Revenue Event，随后与支付收入共用同一分账、账本和开发者余额体系。

首期事件类型面向 impression/click/conversion/rewarded-complete 扩展，不允许未经验证的客户端事件直接产生可提现余额。

## 开发者余额与提现

开发者收益四个状态：

1. Pending：已记账但仍处退款/反作弊/结算等待期。
2. Available：可申请提现。
3. Reserved：已提交 payout，资金被锁定。
4. Paid：PSP 已确认打款完成。

提现状态机：`requested -> reviewing -> processing -> paid`，允许明确的 failed/cancelled 退出，但禁止 `requested -> paid` 直接跳转。

第一阶段由持牌 PSP/marketplace payout provider 托管实际资金并执行 KYC/KYB/payout；Fabushi 负责商业规则、账本、余额和结算编排，不自行充当资金托管机构。

## Provider Adapter

必须支持：

- Apple In-App Purchase / StoreKit（虚拟商品场景遵循平台规则）
- Google Play Billing（虚拟商品场景遵循平台规则）
- Stripe/Adyen/其他 marketplace provider（适用场景）
- 支付宝及地区支付渠道

Adapter 的职责是验证外部事实并产生标准事件，而不是各自维护余额或权益真相。

## Refund / Chargeback

退款和拒付不得删除或修改历史 journal。必须生成引用原事件的 reversal Revenue Event / reversal journal，通过相反账务分录恢复正确状态，并保持 webhook 幂等。

## 合规与风险边界

需要长期覆盖：平台规则、KYC/KYB、税务、退款/chargeback、对账、广告审核、广告反作弊、隐私同意、未成年人保护与 payout 风控。通用可转让/可提现用户储值余额不属于 V1 范围；如未来启用，必须先做对应支付/电子货币监管评估。

## 当前 V1 落地

- migration: `fabushi/web/migrations/20260825_monetization_platform_v1.sql`
- domain core: `fabushi/web/src/services/monetization.js`
- D1 persistence: `fabushi/web/src/services/monetization-store.js`
- invariant tests: `fabushi/web/tests/monetization.test.js`
- task record: `../management/tasks/M9-T06-monetization-core.md`

下一阶段：active split-rule resolver -> 现有支付 provider Revenue Event adapter -> refund reversal -> entitlement migration -> verified ads -> PSP payout。

重要原则：支付/商业化系统不要和聊天 UI 直接耦合；Chat/MiniApp 只消费 Payment/Entitlement/Monetization 领域事件。
