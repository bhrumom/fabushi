# 2026-08-25 动态法币 Mini App Commerce 需求

- Project: `FAB-P0001 / TFI`
- Stage: `M9 支付`
- Requirement status: `ACTIVE`
- Source: 2026-08-25 用户决策

## 产品决策

Fabushi 的第三方 Mini App 数字商品采用**直接法币标价**，不强制经过 Fabushi Stars/FBC。平台币/credits 可以继续作为可选支付 rail，但不得成为数字商品的必经中间层。

开发者只维护 Fabushi Developer Commerce 商品目录：`miniAppId + sku + productKind + entitlement capability + fiat currency + integer minor-unit price + subscription period + localized metadata`。开发者不得直接控制平台费率、开发者身份、商店凭证或结算账户归属。

Fabushi Host 根据平台把同一 canonical SKU 映射到：

1. iOS：Apple Advanced Commerce / Mini Apps Partner Program。Fabushi 自托管 SKU 目录，App Store Connect 只维护平台获得资格后所需的 generic product identifiers；运行时生成 Apple 所需的动态 SKU/价格授权材料。
2. Android：Google Play Billing + Android Publisher API 自动同步商品/订阅，避免开发者人工维护 Play Console SKU。
3. Web/Desktop：Fabushi Pay web/merchant provider rail。
4. 所有 rail 最终进入同一 `PaymentIntent -> provider verification/webhook -> balanced ledger -> entitlement -> developer pending/available settlement` 数据面。

`global-dharma` 只是官方开发者名下的第一个普通 Mini App，必须使用与第三方相同的 owner/catalog/price revision/provider binding/entitlement 流程，不允许支付内核出现 Global Dharma 特判。

## 合规/运营边界

代码必须 fail closed：Apple Advanced Commerce / Mini Apps Partner Program 资格、generic product IDs、Apple/Google 凭据或商店商品状态未就绪时，只能返回 `pending_configuration` / `pending_sync`，不能伪装成可购买。实际商店批准、合同签署、税务与地区资格不是代码能够代替的步骤。
