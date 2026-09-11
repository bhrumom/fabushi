# Developer Commerce Catalog 运维手册

## 适用范围

本手册适用于第三方开发者通过 Developer Commerce API 批量创建/更新 Mini App 商品、同步 Google Play 商品和执行 catalog reconciliation。官方 `global-dharma` 也必须走这条路径。

## 发布前检查

1. 从 GitHub Actions 对 accepted `main` SHA 构建并部署 Worker/D1 migration；不在开发机执行生产 migration。
2. 确认 `catalog_source` migration 已应用，历史官方商品仅增加 adoption audit，product/order/entitlement ID 未改变。
3. 确认开发者调用使用平台认证和 Mini App access；客户端 bundle、renderer 和日志中不得出现 provider secret。
4. 确认 Google service-account 权限和外部 Play product/base-plan 状态；资格不完整时应保持 `pending_sync`/`error`。

## 日常操作

- 商品写入：调用 `POST /v1/developer/commerce/mini-apps/:mini_app_id/products/batch`。
- Google 批量同步：调用 `POST /v1/developer/commerce/mini-apps/:mini_app_id/google/sync`。
- 商品列表：检查 `providerBindings` 的 `syncState`，不要仅依据本地 product `active` 判断可购买。
- 对账：执行控制面定时 reconciliation；只重试幂等同步，不删除历史产品或支付事实。

## 回滚与故障处置

- 新代码异常时可以回滚应用版本，但不得删除 `catalog_source`、adoption audit、历史订单或 entitlement。
- Google API 超时/权限错误时保持 provider binding 非 active，记录逐项错误并在下一次对账重试。
- 若发现跨 Mini App 写入，立即停用受影响 API 凭据/访问边界，保留 audit 和 provider response，按安全事件流程处理。
- 生产 Stripe、支付宝、Apple、Google 的签约/审核/税务/银行资料属于外部门禁；没有客观证据时不得手工改成 active。
