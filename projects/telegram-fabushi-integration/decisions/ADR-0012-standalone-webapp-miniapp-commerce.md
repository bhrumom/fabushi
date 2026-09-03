# ADR-0012 — 独立 Web App 是一等 MiniApp；Fabushi 是可选增强层

- **状态**：Accepted
- **日期**：2026-08-27
- **Project**：FAB-P0001 / TFI
- **Context**：M8 Mini Apps / Marketplace / WebMCP / Commerce

## 决策

Fabushi MiniApp 不要求应用只能存在或运行于 Fabushi。一个公开 HTTPS Web App 可以首先是一套完全独立的产品；上架 Fabushi 后，Fabushi 为它增加市场发现、Bot、WebMCP/MCP、身份与批准机制，但不成为该应用运行的前提。

对于电商应用：

1. 浏览器用户直接访问独立域名并使用普通 storefront 完成购物。
2. Fabushi listing 的 `web` surface 指向同一个独立站，而不是复制页面。
3. listing 的 `mcp-http` / WebMCP tools 操作同一个 commerce backend。
4. AI 不以 DOM/视觉点击作为规范业务接口；商品搜索、cart、checkout、order 通过结构化 Tool Contract。
5. 商品、价格、库存、cart、order 的 authority 属于 commerce backend；Fabushi 不复制第二份电商账本。
6. `add_to_cart`、checkout preparation 等写操作继续走宿主 approval；最终 `place_order` 为 destructive approval。
7. Web App 必须能在没有 Fabushi SDK 的普通浏览器中工作；检测到 Fabushi 环境时只启用增强能力。

## 第一实现

首个 reference implementation 使用 Medusa 官方 DTC Starter（MIT）固定上游 commit `cb603dfda0a82e8bb5e81622f295e0ff90ac6913`。Fabushi 以 overlay 增加发现 manifest、AI Commerce MCP 和部署配置。

## 备选方案与拒绝原因

- **Fabushi-only 内嵌网页**：拒绝。会损失 SEO、广告直达、普通浏览器购买和独立品牌域名。
- **AI 只操作网页 DOM**：仅作兼容 fallback，不作为正式 commerce contract；页面改版会破坏可靠性，也难以正确表达审批与幂等。
- **Fabushi 自建第二套 cart/order**：拒绝。会产生价格、库存、退款和订单状态双写问题。
- **从零重写电商内核**：拒绝。SKU、库存、促销、税、配送、支付、退款边界已经有成熟开源实现。
- **归档的 Medusa Next starter**：拒绝。使用仍在维护的官方 DTC Starter。

## 结果

未来 Shopify、WooCommerce、Medusa、自研站点或 SaaS 都可以通过相同原则上架：公开 Web URL + 可验证 manifest + 结构化 Tool Contract。Fabushi 的市场成为应用分发和 Agent 增强层，而不是封闭宿主。
