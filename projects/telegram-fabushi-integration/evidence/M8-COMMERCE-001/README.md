# Evidence — M8-COMMERCE-001

日期：2026-08-27
状态：IN_PROGRESS / DEPLOYMENT_BLOCKED
实现 PR：`#2184`
实现分支：`feat/tfi-m8-standalone-commerce`
最终 PR head：`2cc126c10dc4d1320df98bf106679c273f5c19b3`
canonical main SHA：`4d5fac6787c62ee881d65cfe212b2b4f15a80584`

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

## PR / CI / protected main evidence

- PR `#2184` final head：`2cc126c10dc4d1320df98bf106679c273f5c19b3`。
- PR-head `Standalone commerce site` run `33064741725`：`success`；真实执行了 upstream materialize、依赖安装、Medusa backend build、storefront TypeScript check、production compose validation。
- PR-head canonical `CI` run `33064741960`：`success`；Project portfolio governance 与 Developer Fiat Commerce 也为 `success`。
- 仓库 ruleset `main-merge-queue` 强制 protected merge queue，required status 为 `CI result`，不能直接绕过。
- PR 在 merge queue position 1 上创建 merge-group SHA `4d5fac6787c62ee881d65cfe212b2b4f15a80584`；merge-group CI run `33065058090` 的 `CI result` 和所有被选择的 jobs 均为 `success`。
- PR 于 `2026-08-27T10:56:41Z` 合并。
- canonical `main` 回读确认 HEAD 为 `4d5fac6787c62ee881d65cfe212b2b4f15a80584`，且 `ai-backend/src/standalone_commerce_miniapp.js` 与 `commerce/fabushi-store/upstream.lock.json` 可从该精确 SHA 读取。

## 公网运行证据待补

以下项目尚未形成真实 evidence，不得标记 RELEASED：

1. `https://shop.ombhrum.com` HTTPS 200、页面截图/浏览器 trace。
2. `https://shop.ombhrum.com/.well-known/fabushi.json` 200 + schema readback。
3. `/api/fabushi/mcp` initialize、tools/list、search_products、create_cart、add_to_cart、prepare_checkout 测试。
4. Fabushi production marketplace API 搜索并添加 `fabushi-store`。
5. AI cart handoff 后浏览器 checkout 命中同一 cart 的 E2E。
6. 若启用真实卡支付：真实/Provider sandbox purchase + webhook/order 状态证据；未配置时必须明确标识为非真实扣款环境。

## 当前部署阻塞记录

- Oracle/grokbot VPS connector 本轮持续返回 HTTP 502（`vps_status` 与 `run_shell_command`），没有可验证生产主机执行通道。
- 直接 DNS/HTTPS 探针显示 `shop.ombhrum.com` 与 `shop-api.ombhrum.com` 当前无法解析，因此不能宣称公网已经上线。
- 本任务没有发现或注入真实 merchant payment-provider secret；真实卡扣款仍不得宣称可用。

代码、市场模型、AI Commerce contract 和生产部署资产已经进入 `main`；任务保持 `IN_PROGRESS / DEPLOYMENT_BLOCKED`，直到上述公网证据闭环。
