# M9-PAY-002-CATALOG-API-001 — Developer-owned batch catalog and reconciliation

- Project: `FAB-P0001 / TFI`
- Project Key: `TFI`
- Stage: `M9 支付`
- Status: `IN_PROGRESS / MERGED_POST_MAIN_PENDING`
- Started: `2026-09-11`
- Updated: `2026-09-11`
- Owner surface: Developer Commerce / Platform Control Plane / Fabushi Pay / Desktop BotFather
- Source: `../../source/2026-09-11-developer-commerce-catalog-api.md`
- Related task: `M9-PAY-002-dynamic-fiat-developer-commerce.md`
- Related ADR: `../../decisions/ADR-0015-developer-owned-commerce-catalog-provisioning.md`

## Objective

将商品目录的写入、价格版本、Google Play 上架同步和对账统一收敛到第三方开发者 Developer Commerce API。官方 `global-dharma` 不再使用独立内置商品路径，而是作为普通开发者商品目录的真实消费者。

## Source requirements

- `M9-PAY-002-G`: BotFather / Developer Commerce 可由开发者管理法币 SKU，renderer 不持有支付凭据。
- `M9-PAY-002-F`: `global-dharma` 使用与第三方 Mini App 相同的 owner/catalog/price/provider binding 流程。
- `M9-PAY-002-CATALOG-API-001-R01`: 第三方开发者批量创建/更新商品并保留价格 revision。
- `M9-PAY-002-CATALOG-API-001-R02`: Google Play 同步和定时 reconciliation 由服务端控制面执行。
- `M9-PAY-002-CATALOG-API-001-R03`: 历史官方商品只做 adoption，不重新 seed，不破坏历史订单/权益。
- `M9-PAY-002-CATALOG-API-001-R04`: 支付宝保持 APP 支付，不回退为当面付。

## In scope

- authenticated developer batch product upsert，以 `mini_app_id + sku` 为稳定键；
- server-side product/price/provider-binding/audit 写入和结果状态；
- Google Publisher API 批量同步、区域价格转换、base-plan 激活和定时缺失/过期对账；
- platform proxy、Electron native bridge、BotFather UI 和 contract tests 迁移到批量 API；
- forward-only `catalog_source` adoption migration；
- Developer Commerce / Fabushi Pay 文档、runbook、风险和证据索引。

## Out of scope

- Apple Advanced Commerce 审批、generic product ID、税务/银行资料或真实生产凭据；
- Google Payments profile、生产付款方式、商店人工审核或真实扣款；
- Stripe/支付宝生产商户签约、webhook secret 和真实资金 smoke；
- 删除历史商品/订单/entitlement，或建立第二支付账本；
- 本地 application build、native/mobile package 或 E2E 执行。

## Dependencies and blockers

- fresh canonical `main` base `e2d4eda0c449e461771b855aaeee416062512f09`；
- GitHub Actions required CI、protected merge queue、canonical-main readback；PR #2504 已合并，但 exact-main 打包/E2E/视觉证据仍待完成；
- production Google/Apple/Stripe/支付宝资格和凭据是后续外部激活门禁；
- migration/deploy 需要平台 D1/Worker 发布权限，未部署前不能声称线上已同步。

## Acceptance criteria

| ID | Criterion | Verification / evidence | State |
|---|---|---|---|
| A1 | 所有商品写入均为 developer/app authorized API，不能由客户端指定 owner、developer、platform fee 或 provider secret | Rust worker contracts + platform proxy + desktop bridge tests | IMPLEMENTED / MERGE_GROUP_GREEN; exact-main follow-up |
| A2 | 批量 upsert 支持新增/更新、重复 SKU 拒绝、价格变化追加 revision，已有 product ID 保持不变 | commerce-control tests + schema/migration inspection | IMPLEMENTED / MERGE_GROUP_GREEN; exact-main follow-up |
| A3 | Google sync 一批只取得一次 Publisher token，执行 region price conversion、商品/订阅同步、base-plan 激活并返回逐项结果 | Google adapter contracts + GitHub Actions | IMPLEMENTED / MERGE_GROUP_GREEN; runtime sync pending |
| A4 | scheduled reconciliation 能发现 Google catalog 缺失或过期 binding，并保持 fail-closed 状态 | Rust control-plane tests + exact-main scheduled/runtime evidence | IMPLEMENTED / POST_MAIN_PENDING |
| A5 | `global-dharma` 只通过同一 developer API；adoption migration 保留历史 product/order/entitlement | migration contract + D1 migration evidence | IMPLEMENTED / CANONICAL_READBACK |
| A6 | 支付宝配置/文档/测试明确为 APP 支付，不存在当面付调用 | Node contract tests + source inspection | IMPLEMENTED / CANONICAL_READBACK |
| A7 | 必要 CI、protected merge、canonical main readback、打包用户旅程和证据闭环 | GitHub Actions / PR / post-main artifacts | IN_PROGRESS / POST_MAIN_PENDING |

## Verification policy

本轮仅做轻量本地检查（文件、差异和 `git diff --check`）；不在开发机运行构建、Rust/Node 全量测试、native/mobile、模拟器或打包。重型验证必须在 GitHub Actions 完成。此前已有的本地预检不能替代本 PR 的 exact-head CI 和 post-main packaged evidence。

## Open-source-first survey

审阅了 Saleor（BSD-3-Clause）、Vendure（GPLv3/commercial dual license）和 Medusa（open-core，核心 MIT）的公开仓库 README、目录/渠道/扩展/测试模型及许可证。结论已记录在 `ADR-0015`：只采用 API-first catalog、versioned price、extension boundary 和测试分层的设计经验，不复制代码、不引入依赖；Fabushi 继续使用 Rust/D1/唯一 Pay ledger。

## Implementation summary

- 新增 developer batch product upsert 与 Google batch sync/reconcile control-plane routes；
- provider binding/list projection 明确暴露同步状态；
- 删除旧的 admin product create/update route；
- `catalog_source` adoption migration 将历史官方行标记为 developer API 目录，不重建商品；
- Electron / BotFather / Platform proxy / contract tests 迁移至 developer batch path；
- 支付宝保持 `alipay.trade.app.pay` APP 支付路径。

## Branch / commit / PR

- Branch: `codex/m9-pay-002-catalog-api-20260911`
- Local preparation commit: `505697475`
- Remote PR head: `b0489a9a9820eb0f600123d6468bc64e405a804a`
- Pull request: `#2504` against `main`
- Merge SHA: `e218e602130ed9a1e927f55c89faa175cdb368f0`
- Merged at: `2026-09-11T07:46:30Z`; merge-group CI run `34575923650` passed.
- Canonical-main readback: `main@e218e602` contains the developer catalog migration and APP-pay configuration; push-triggered exact-main delivery runs remain in progress/queued at this update.

## Evidence plan

- `evidence/M9-PAY-002-CATALOG-API-001/README.md`
- PR-head required Actions and job logs;
- merge-group / protected-main result;
- canonical-main migration and exact-main control-plane/package/E2E evidence;
- required screenshot/video/trace/report/log bundle for packaged application journeys.

## Risks

- developer authorization or batch validation regression could allow cross-app catalog writes;
- provider sync failure could be mistaken for a purchasable product;
- adoption migration must remain forward-only so historical financial facts cannot be rewritten;
- external provider approval remains outside code and must stay fail-closed.

## Next action

PR #2504 已合并到 canonical `main@e218e602` 并完成初步文件回读。下一步是等待/检查该 SHA 的 exact-main 控制面、打包应用、模拟用户 E2E 及视觉/调试证据，并在必要时发布可追溯 Release；同时保持 Google/Apple/Stripe/支付宝的外部资格门禁 fail-closed。Keep this task `IN_PROGRESS` until the required post-main gates and external activation evidence are separately satisfied.
