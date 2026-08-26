# M9-PAY-002 Dynamic Fiat Developer Commerce

- Project: FAB-P0001 / TFI
- Stage: M9 支付
- Status: COMPLETE
- Owner surface: Developer Commerce / Bot Father / Fabushi Pay

## 目标

让第三方 Mini App 直接以法币定义数字商品价格，由 Fabushi 托管 canonical catalog；iOS 使用 Apple Advanced Commerce 动态 SKU，Android 由 Publisher API 自动同步 Play Catalog，Web/Desktop 继续使用 Fabushi Pay。所有平台共享 PaymentIntent、provider verification、ledger、entitlement、developer settlement。

## 原子验收项

| ID | 验收条件 | 客观测试 | 状态 |
|---|---|---|---|
| M9-PAY-002-A | Developer Commerce 按登录用户/角色授权，客户端不能指定 developerId/owner/platform fee | schema-contract + Rust tests + desktop bridge contract | COMPLETE |
| M9-PAY-002-B | 商品使用 ISO 法币 + integer minor units；价格修改产生新 price revision | Rust + schema contract + HTTP contract | COMPLETE |
| M9-PAY-002-C | Apple Advanced Commerce 使用 generic product + 动态 SKU + server ES256 JWS；未配置 entitlement/key/tax code 时 fail closed | Rust + wasm compile + JWS contract | COMPLETE |
| M9-PAY-002-D | Google Play 先通过 `pricing:convertRegionPrices` 生成全球地区价格，再用 Publisher API 同步商品；失败进入 error，不伪装 active | Rust + wasm compile + adapter contract | COMPLETE |
| M9-PAY-002-E | PaymentIntent 仍只从服务端 catalog 取价格，Mini App 不提交可信 amount/currency；只有 active provider binding 可进入 allowed rails | existing Fabushi Pay tests + contract test | COMPLETE |
| M9-PAY-002-F | global-dharma 只作为 official.fabushi 名下普通 Mini App 使用同一 catalog/owner/provider binding | migration contract | COMPLETE |
| M9-PAY-002-G | Bot Father 可创建开发者身份、注册 Mini App、创建/改价法币 SKU、查看/触发商店同步，renderer 不持有支付服务凭据 | web build + native bridge contract | COMPLETE |
| M9-PAY-002-H | CI 绿后通过 PR 合并 canonical main，并在 exact-main SHA 再跑门禁 | GitHub Actions + exact-main verification | COMPLETE |

## 已落代码面

- `0008_dynamic_fiat_developer_commerce.sql`：owner/member/catalog/price revision/provider binding/audit schema。
- `0009_global_dharma_dynamic_fiat_seed.sql`：¥30/月、¥1080 永久版作为普通 canonical SKU 种子。
- `mahayana-commerce-control-worker`：owner-scoped Developer Commerce API、Apple Advanced Commerce JWS、Google Publisher catalog sync。
- Google 同步采用 `convertRegionPrices -> convertedRegionPrices/otherRegions/regionVersion -> catalog write`，不再只写单地区价格。
- Provider purchase rail 采用 fail-closed：`payment_product_config.allowed_rails_json` 只包含 `sync_state=active` 的绑定；Google 同步成功后才激活 `google_play_billing`。
- `api.ombhrum.com` 平台 Worker 只代理白名单 Developer Commerce 路由，拒绝 admin pay surface。
- Bot Father `/miniapps/bot-father/commerce` 管理面使用 `window.fabushiNative.invoke`，宿主注入登录态；前端请求无法指定 developerId / ownerUserId / platformFeeBps。
- Apple Advanced Commerce 校验同时绑定 generic product ID、persisted dynamic Mini App SKU、request reference、appAccountToken、currency、tax code 与 item price；结算收入仍以 provider reconciliation 为财务权威。

## 完成证据

- 主实现 PR：`#2133` — `[automerge-force] feat(pay): dynamic fiat commerce with global and mainland China payouts`。
- 最终 feature head：`4d0687fed9b54793cb1237c39718b51b8d32b669`。
- feature-head 验证：Developer Fiat Commerce run `32868752808` 5/5 success；Developer Fiat Commerce UI run `32868752819` 2/2 success；Platform Control Plane run `32868752821` success；CI run `32868752829` success；Electron desktop quality gate run `32868752823` success。
- Protected Merge Queue：merge-group CI run `32869281732` success。
- canonical `main` 合并 SHA：`573c140f7007ad98230c90f3c24bc99e1f36a88f`，PR #2133 merged at 2026-08-25T16:01:48Z。
- exact-main 验证：Developer Fiat Commerce run `32869457305` 5/5 success；Developer Fiat Commerce UI run `32869457162` 2/2 success；Platform Control Plane run `32869457301` success。Merge Queue CI 已在同一 exact SHA `573c140f...` 上 success。

## 外部资格门禁

工程实现与 canonical-main 验收已完成；这不等于第三方支付渠道已经取得生产资格。Apple Mini Apps Partner Program / Advanced Commerce entitlement、generic product IDs、IAP signing key，以及 Google Play service-account 权限仍属于外部平台激活条件。缺失批准/凭据时 provider 必须保持 fail closed，不得报告为生产可用。
