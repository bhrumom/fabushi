# Evidence — M8-COMMERCE-001

日期：2026-08-27
状态：IN_PROGRESS / TESTING
分支：`feat/tfi-m8-standalone-commerce`

## 已完成并有仓库证据

- 开源底座：`medusajs/dtc-starter`，MIT，pin `cb603dfda0a82e8bb5e81622f295e0ff90ac6913`。
- provenance：`commerce/fabushi-store/upstream.lock.json`。
- reproducible materialization：`commerce/fabushi-store/scripts/materialize.sh`。
- production topology：`commerce/fabushi-store/overlay/docker-compose.production.yml` + backend/storefront Dockerfiles + Caddyfile。
- public discovery：`commerce/fabushi-store/overlay/apps/storefront/public/.well-known/fabushi.json`。
- AI Commerce MCP：`commerce/fabushi-store/overlay/apps/storefront/src/app/api/fabushi/mcp/route.ts`。
- AI cart -> browser checkout handoff：`commerce/fabushi-store/overlay/apps/storefront/src/app/api/fabushi/cart/claim/route.ts`。
- Fabushi listing：`ai-backend/src/standalone_commerce_miniapp.js` + production bootstrap seed。
- marketplace contract test：`ai-backend/test/standalone_commerce_miniapp.test.js`。
- CI gate：`.github/workflows/standalone-commerce-site.yml`。

## 运行证据待补

以下项目尚未形成真实 evidence，不得标记完成：

1. PR number / final head SHA / required checks。
2. merge commit / canonical main SHA。
3. `https://shop.ombhrum.com` HTTPS 200、页面截图/浏览器 trace。
4. `https://shop.ombhrum.com/.well-known/fabushi.json` 200 + schema readback。
5. `/api/fabushi/mcp` initialize、tools/list、search_products、create_cart、add_to_cart、prepare_checkout 测试。
6. Fabushi production marketplace API 搜索并添加 `fabushi-store`。
7. AI cart handoff 后浏览器 checkout 命中同一 cart 的 E2E。
8. 若启用真实卡支付：真实/Provider sandbox purchase + webhook/order 状态证据；未配置时必须明确标识为非真实扣款环境。

## 当前部署阻塞记录

本轮两次 Oracle VPS connector 调用均返回 HTTP 502（`vps_status` 与 `run_shell_command`），因此没有伪造 VPS 或公网部署结果。后续只在连接恢复并完成实际探针后更新本文件。
