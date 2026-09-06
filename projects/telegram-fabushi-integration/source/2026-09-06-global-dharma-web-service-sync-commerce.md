# 2026-09-06 — 全球法布施 Web / 服务端状态同步与 Commerce closure

- Project: `FAB-P0001 / TFI`
- Cross-project governance: `FAB-P0008 / AAC`
- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Execution branch: `feat/tfi-global-dharma-web-service-sync-pay-20260906`
- Owner surface: Web / AI backend / Marketplace / canonical Fabushi Pay integration

## 用户要求

从 canonical main 真实推进并验证全球法布施 Mini App Web/服务端主线：

1. Marketplace 搜索“全球法布施”必须发现并可安装 official `global-dharma`；安装状态投影同一个 `global_dharma_bot`。
2. Bot 自然语言、slash command、WebMCP `tools/list` / `tools/call` 必须消费一个 canonical Tool Contract，不能维护可漂移的第二套命令表。
3. Bot 调用与 Telegram 类“打开应用”Web UI 必须共享一个账户级运行状态：单调事件序列、断线后 cursor difference/snapshot 恢复、写操作 idempotency、写/外部/破坏性操作显式权限确认。
4. 已登录 Fabushi 账号自动获得受控 Mini App session；Mini App/WebMCP 不得拿到原始 access/refresh token。账户身份由 server/host 解析并作为 durable account namespace。
5. 本地转经轮 lifetime entitlement 价格固定为服务端 catalog 的 CNY `108000` minor units；支付必须沿 canonical Fabushi Pay PaymentIntent/Order/provider webhook/idempotency/refund/reconciliation/entitlement 边界。Mini App 客户端状态不能解锁 `local.prayer-wheel.start`。
6. 必须建立可复现 contract/integration evidence，并协调 packaged-user journey：搜索 -> 安装 -> Bot -> 自然语言 -> tools/list -> tools/call -> 打开应用 -> 同步 -> 支付/恢复 entitlement -> capability 可用。
7. 重型构建、packaged E2E、provider sandbox 只在 GitHub Actions；缺少真实 provider sandbox、发布包、设备或完整视频必须 fail closed，不得伪造通过或链接。

## Canonical main 审计事实

- `M8-WEBMCP-001` PR #2169 已于 2026-08-27 合并为 `fefb35fc8a4e5c8dabecc9c11803764ec950b6e9`，项目 task 仍残留 pre-merge closure 文案。
- `WebMcpMiniAppAdapter.tsx` 已执行 `initialize -> tools/list -> expose WebMCP -> tools/call`，写操作保留浏览器确认，但不订阅 durable business-state stream。
- `McpPluginApp.tsx` 的 MCP GET stream 支持 `Last-Event-ID` 重连；当前 MCP `MemoryEventStore` 只覆盖进程内 session event，并不是 Bot/UI 共用的业务状态权威。
- `official_mcp_apps.js` 的 `stateByScope = new Map()` 以 user scope 隔离，但状态在进程内存中；重启/多实例会丢失 Global Dharma `mode/running/loops/sent/logs/pendingContent`。
- `AccountSyncStore` 已使用 SQLite/WAL 实现 `as1:<sequence>`、durable journal、retention floor、difference、cursor-ahead/expired snapshot recovery、account isolation；应复用而不是再造第二套 event store。
- Marketplace official seed 已存在 `global-dharma`、中文 title、`global_dharma_bot`、remote MCP/Web/CLI surfaces 与 NLU hints；但 manifest `commands` 是手写列表，而 live MCP server 注册的 Tool inventory 更大，存在 drift 风险。
- `M9-GLOBAL-DHARMA-003` Round A PR #2135 已合并为 `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`；canonical catalog 中 monthly CNY 3000 / lifetime CNY 108000 与 `local.prayer-wheel.start` server-side entitlement policy 已存在。
- `M9-PAY-002` 已证明 canonical Fabushi Pay 具备 server-authoritative Product/Price/PaymentIntent、provider verification/webhook、ledger、refund/reversal、entitlement、reconciliation；本轮不得创建第二账本。

## Open-source-first 启动门禁

在实现前审阅：

- Model Context Protocol TypeScript SDK：Apache-2.0（新贡献）/ MIT（既有代码）；Streamable HTTP 支持 `eventStore` 与 `Last-Event-ID` resumability。继续使用仓库既有 MCP SDK，不复制实现。
- TDLib：Boost Software License 1.0；其 update/difference + gap recovery 设计与现有 `as1` 模型一致。只学习状态机，不复制 MTProto/TL。
- NATS JetStream：Apache-2.0，成熟 durable consumer，但引入它会产生第二个 durable event authority 和新运维面；拒绝引入，复用现有 SQLite account journal。
- Auth.js：ISC；Better Auth：MIT。两者均可用于 Web session，但 Fabushi 已有 canonical account/session 与 `/api/auth/user-info` identity boundary；拒绝引入平行认证栈。
- Stripe Node SDK：MIT；其稳定 idempotency identity / duplicate webhook handling 仅作支付设计交叉检查。Fabushi 已有 canonical Rust Pay inbox/idempotency/reversal，不引入 Stripe 专属账本或客户端真相。

## 设计决定

1. 扩展现有 `AccountSyncStore`，增加 account + MiniApp scoped runtime snapshot 与 idempotent tool-operation receipt，并把 runtime mutation 写入同一个 `account_sync_events` sequence。
2. Global Dharma MCP server 不再以 `stateByScope` 作为 durable authority；每次 tools/call 从 runtime store 读取/原子提交，并返回 `{runtime:{revision,cursor,state}}`。
3. Web/服务端暴露 authenticated runtime state/difference API，cursor 复用 `as1`；UI 可先取 snapshot，再按 cursor 拉 difference。MCP session `Last-Event-ID` 仍只负责协议级通知恢复，不承担业务状态权威。
4. Marketplace/Bot 命令目录由 canonical Global Dharma Tool Contract 生成；WebMCP、Bot NLU、Marketplace command catalog 只消费该 contract。
5. 权限由 tool annotations/contract approval metadata 决定；服务端 mutation 要求 request/idempotency key，重复 key 返回原 receipt，不重复 side effect。
6. Account session 只由 `resolveUser`/stable user id 进入 MCP/runtime/commerce；浏览器 `credentials: include` 或 Host bearer 只作为 transport credential，Mini App payload 不包含 raw token。
7. 支付层只增加 Web/AI-backend facade/contract 验证（如现有路由缺失）；资金、provider callback、refund/reconciliation 和 entitlement authority 始终是 canonical Rust Fabushi Pay。

## 安全不变量

- raw Fabushi token、refresh token、PSP secret、provider credential 不进入 Mini App Tool args/state/event。
- amount/currency/SKU/capability/provider rail 由服务端 catalog 决定。
- `local.prayer-wheel.start` 在实际 capability dispatch 前必须 server-authoritative entitlement check，不能只靠 UI 禁用按钮。
- same idempotency key + same operation 返回同一结果；same key + different operation/args 必须 409/fail closed。
- account cursor/event 永不跨 account 泄露；logout/session revoke 后不能继续读取旧 account runtime。
- test mode 必须显式、CI-only，不能成为 production entitlement source。
