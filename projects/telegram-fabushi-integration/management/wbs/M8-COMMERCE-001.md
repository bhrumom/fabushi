# WBS 原子任务 — M8-COMMERCE-001 独立站 + AI Commerce

## M8.T13.1 — 开源底座与独立 Web storefront
- **交付物**：Medusa DTC Starter pinned-upstream overlay、Next storefront、Postgres/Redis/Medusa production topology。
- **验收标准**：站点无需 Fabushi 即可从公开 HTTPS 浏览商品、cart、checkout；上游 SHA/许可证可追溯。
- **客观验证**：`standalone-commerce-site.yml` materialize + backend compile + storefront typecheck + compose config；生产 HTTPS probe/E2E。
- **状态**：TESTING / IN_PROGRESS
- **证据位置**：`../../evidence/M8-COMMERCE-001/README.md`

## M8.T13.2 — 外部站点上架 Fabushi Marketplace
- **交付物**：`fabushi-store` approved metadata listing、`/.well-known/fabushi.json`、默认 Bot、web + mcp-http surfaces。
- **验收标准**：普通浏览器入口保持独立；Fabushi 搜索/添加后同一站点可由 MiniApp/Bot 打开和驱动；marketplace 不代理站点 bytes。
- **客观验证**：`ai-backend/test/standalone_commerce_miniapp.test.js` + production marketplace search/add readback。
- **状态**：TESTING / IN_PROGRESS
- **证据位置**：`../../evidence/M8-COMMERCE-001/README.md`

## M8.T13.3 — Medusa-backed AI Commerce Tools
- **交付物**：catalog/cart/checkout/order MCP tools + cart handoff。
- **验收标准**：AI 与浏览器共享 Medusa authority；write tools 经 approval；`place_order` 为 destructive；handoff 后 browser checkout 读取同一 cart。
- **客观验证**：MCP initialize/tools/list/tools/call contract + E2E `search -> create cart -> add -> handoff -> checkout`。
- **状态**：TESTING / IN_PROGRESS
- **证据位置**：`../../evidence/M8-COMMERCE-001/README.md`

## M8.T13.4 — 公网部署、支付边界与发布闭环
- **交付物**：`shop.ombhrum.com` / `shop-api.ombhrum.com` production deployment、TLS、provider configuration、PR/main/release evidence。
- **验收标准**：HTTPS/MCP/marketplace probes 全通过；真实支付仅在 provider credentials 配置并验证时宣称可用；PR required checks -> protected main -> canonical main readback。
- **客观验证**：GitHub CI / merge SHA / production curl or browser E2E / screenshots/trace / payment environment evidence。
- **状态**：BLOCKED
- **阻塞**：本轮 Oracle VPS connector HTTP 502；尚未获得可验证生产主机执行；真实 merchant provider secret 尚未发现。
- **证据位置**：`../../evidence/M8-COMMERCE-001/README.md`
