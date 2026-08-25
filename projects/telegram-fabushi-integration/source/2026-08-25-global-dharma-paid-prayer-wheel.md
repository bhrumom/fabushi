# 2026-08-25 — 全球法布施本地转经轮付费门槛

用户要求将统一 Monetization Platform 实际用于官方 `official.global-dharma` 小程序：本地转经轮能力需要付费后才能启动；月付人民币 30 元，买断人民币 1080 元。支付、订阅、权益和退款必须使用 canonical Fabushi Pay，不允许小程序自己用布尔变量代表付款。

## Required product contract

- Mini App: `official.global-dharma`
- Protected capability: `local.prayer-wheel.start`
- Monthly SKU: `local-prayer-wheel-monthly`
- Monthly price: CNY 3000 minor units
- Lifetime SKU: `local-prayer-wheel-lifetime`
- Lifetime price: CNY 108000 minor units
- Monthly is a subscription product; lifetime is durable digital entitlement.
- Both products grant the same protected capability.
- Global sending and unrelated free capabilities remain unaffected.
- Server-side access gate must run before the protected host request is exposed/executed; hiding a button is insufficient.
- Web/desktop uses canonical web-provider checkout where applicable. iOS/Android continue to use the canonical Apple/Google rails and require real store product provisioning before those rails are production-enabled.
- Subscription access must have an effective expiry even if the provider lifecycle notification is delayed; lifetime access has no expiry.
