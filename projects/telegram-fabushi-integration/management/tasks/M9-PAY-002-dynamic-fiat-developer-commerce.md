# M9-PAY-002 Dynamic Fiat Developer Commerce

- Project: FAB-P0001 / TFI
- Stage: M9 支付
- Status: IN_PROGRESS
- Owner surface: Developer Commerce / Bot Father / Fabushi Pay

## 目标

让第三方 Mini App 直接以法币定义数字商品价格，由 Fabushi 托管 canonical catalog；iOS 使用 Apple Advanced Commerce 动态 SKU，Android 由 Publisher API 自动同步 Play Catalog，Web/Desktop 继续使用 Fabushi Pay。所有平台共享 PaymentIntent、provider verification、ledger、entitlement、developer settlement。

## 原子验收项

| ID | 验收条件 | 客观测试 | 状态 |
|---|---|---|---|
| M9-PAY-002-A | Developer Commerce 按登录用户/角色授权，客户端不能指定 developerId/owner/platform fee | schema-contract + Rust tests | IN_PROGRESS |
| M9-PAY-002-B | 商品使用 ISO 法币 + integer minor units；价格修改产生新 price revision | Rust + HTTP contract | IN_PROGRESS |
| M9-PAY-002-C | Apple Advanced Commerce 使用 generic product + 动态 SKU + server ES256 JWS；未配置 entitlement/key/tax code 时 fail closed | Rust + wasm compile + JWS contract | IN_PROGRESS |
| M9-PAY-002-D | Google Play 商品由 Publisher API 服务端同步；失败状态进入 error，不伪装 active | wasm compile + mocked HTTP E2E | IN_PROGRESS |
| M9-PAY-002-E | PaymentIntent 仍只从服务端 catalog 取价格，Mini App 不提交可信 amount/currency | existing Fabushi Pay tests + contract test | IN_PROGRESS |
| M9-PAY-002-F | global-dharma 只作为 official.fabushi 名下普通 Mini App 使用同一 catalog/owner/provider binding | migration contract | IN_PROGRESS |
| M9-PAY-002-G | CI 绿后通过 PR 合并 canonical main，并在 exact-main SHA 再跑门禁 | GitHub Actions + exact-main verification | IN_PROGRESS |

## 外部资格门禁

Apple Mini Apps Partner Program / Advanced Commerce entitlement、generic product IDs、IAP signing key，以及 Google Play service-account 权限属于外部平台配置。代码必须实现完整适配并在缺失时 fail closed；没有外部批准/凭据不得把 provider 状态报告为可用。
