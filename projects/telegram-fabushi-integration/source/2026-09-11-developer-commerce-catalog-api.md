# 2026-09-11 — 第三方开发者目录 API 与官方商品收敛需求

- Project: `FAB-P0001 / TFI`
- Stage: `M9 支付`
- Requirement status: `ACTIVE`
- Source: 2026-09-11 用户明确要求

## 用户决策

所有 Mini App 商品都必须由对应的第三方开发者通过 Developer Commerce API 创建、批量更新和上架；Fabushi 不再为官方 Mini App 保留一套内置商品创建路径。`global-dharma` 也必须作为普通开发者名下的 Mini App，走与其它第三方开发者相同的商品目录、价格版本、商店同步和对账流程。

开发者 API 必须支持：

1. 以 `mini_app_id + sku` 为稳定键的批量创建/更新；
2. 每次价格变化形成新的 server-authoritative price revision；
3. Google Play 商品同步及定时对账；
4. 商品列表能够返回各 provider 的同步状态；
5. 保留历史订单、支付、权益和商品 ID，不通过重新 seed 破坏已有数据。

## 支付渠道约束

- 支付宝使用 APP 支付（`alipay.trade.app.pay` / `QUICK_MSECURITY_PAY`），不是当面付；
- Stripe、支付宝、Apple、Google 的生产开通、凭据、审核、税务和结算资格仍属于外部激活门禁；
- 代码必须 fail closed，不能以配置存在或测试 provider 结果冒充生产可购买。

## 非目标

- 不把 provider 商品 ID、平台费率、开发者身份或结算凭据交给客户端；
- 不建立第二本支付账本；
- 不把 Apple/Google 的外部审核、税务/银行资料或商户签约伪装成代码已完成。
