# M8-COMMERCE-001 — 独立跨境电商站 + Fabushi AI Commerce 上架

- **Project**: FAB-P0001 / TFI
- **Milestone**: M8 Mini Apps
- **Status**: IN_PROGRESS / TESTING
- **Source**: `../../source/2026-08-27-standalone-commerce-miniapp.md`
- **Decision**: `../../decisions/ADR-0012-standalone-webapp-miniapp-commerce.md`
- **Evidence**: `../../evidence/M8-COMMERCE-001/README.md`
- **Branch**: `feat/tfi-m8-standalone-commerce`

## 目标

交付一个本身可在公网浏览器独立运行的 DTC 电商站。它被 Fabushi 市场收录后，同一个应用再通过 `web` + `mcp-http` surfaces 获得 Bot/AI 操作能力；普通浏览器购物不依赖 Fabushi。

## Open-source-first gate

采用 Medusa 官方 `medusajs/dtc-starter`，固定 commit `cb603dfda0a82e8bb5e81622f295e0ff90ac6913`，MIT。该 starter 是当前官方 production-ready DTC monorepo，包含 Medusa v2 backend + Next.js storefront、商品/variant、购物车、checkout、账户与订单管理。

拒绝旧 `medusajs/nextjs-starter-medusa`：官方仓库已经 archive，并迁移到 DTC Starter。

采用 pinned-upstream + overlay，而不是长期复制 fork：`commerce/fabushi-store/upstream.lock.json` 锁定来源，`scripts/materialize.sh` 验证 SHA 后覆盖 Fabushi 文件。

## 原子验收任务

### A1 — 独立站基础
- [x] 固定成熟开源上游与许可证来源。
- [x] 建立可重复 materialize overlay。
- [x] 提供 Postgres + Redis + Medusa + Next 生产容器配置。
- [x] 增加独立站品牌 metadata 和 SEO index/follow。
- [ ] 公网 `https://shop.ombhrum.com` 200 + TLS 探针通过。

### A2 — 独立站 Fabushi discovery
- [x] `/.well-known/fabushi.json` 声明独立 Web entry 和 AI endpoint。
- [x] Fabushi production marketplace seed 增加 `fabushi-store`。
- [x] listing 为 metadata-only，不由 Fabushi 代理站点 bytes。
- [x] 默认 Bot、web surface、mcp-http surface 可从同一 manifest 获得。
- [ ] 生产市场 API 搜索 `fabushi-store` 命中。

### A3 — AI Commerce contract
- [x] `search_products`
- [x] `get_product`
- [x] `create_cart`
- [x] `get_cart`
- [x] `add_to_cart`（required approval）
- [x] `remove_from_cart`（required approval）
- [x] `prepare_checkout`（required approval）
- [x] `place_order`（destructive approval）
- [x] AI 和浏览器都操作 Medusa 原生 cart/order，不建立第二账本。
- [ ] 生产 MCP `initialize -> tools/list -> tools/call` 探针通过。

### A4 — AI 到正常 Checkout 交接
- [x] `prepare_checkout` 返回同一 cart 的 storefront handoff URL。
- [x] handoff 写入 DTC 原生 `_medusa_cart_id` cookie 并进入普通 checkout。
- [ ] E2E：AI 建 cart -> add item -> handoff -> 浏览器 checkout 看见同一商品。

### A5 — 生产支付边界
- [x] 代码不提交 Stripe/PayPal/provider secret。
- [x] 未配置真实 Provider 时文档明确不得宣称真实扣款。
- [ ] 配置真实 merchant provider 或明确使用测试/manual rail，并完成一次对应环境 order E2E。

### A6 — 质量与发布
- [x] 增加 `standalone-commerce-site.yml` 上游 pin / manifest / compile / typecheck / compose 门禁。
- [x] 增加 Fabushi marketplace contract test。
- [ ] PR current-head required checks 全绿。
- [ ] protected merge 到 `main`。
- [ ] canonical-main readback。
- [ ] exact-main 公网站点 + MCP + marketplace E2E evidence。

## 当前阻塞

生产部署通道当前不可用：2026-08-27 本轮调用 Oracle VPS connector 连续返回 HTTP 502。没有可验证的生产主机执行证据，因此公网“已上线”仍保持未完成。真实支付 Provider 凭证也未在本任务中发现或注入。

## 完成定义

只有 A1-A6 所有未勾选项关闭，并且证据目录包含 PR/merge/CI、精确 main SHA、公网 HTTPS、MCP、marketplace search 和 purchase/checkout 测试结果，才可晋级 `COMPLETED / RELEASED`。
