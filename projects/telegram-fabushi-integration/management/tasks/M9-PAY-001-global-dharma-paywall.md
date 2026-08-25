# M9-PAY-001 — 全球法布施本地转经轮付费门槛

- **Project ID**：FAB-P0001
- **Project Key**：TFI
- **Stage**：M9 支付
- **状态**：IN_PROGRESS
- **负责人**：ChatGPT
- **开始日期**：2026-08-25
- **需求来源**：`../../source/2026-08-25-global-dharma-paywall.md`

## 目标

在通用 Fabushi Pay 中实现可复用的 Mini App 能力付费方案，并让全球法布施的 `local.prayer-wheel.start` 成为首个强制付费能力：月付 CNY 30.00、买断 CNY 1080.00。

## 原子验收标准

- [ ] 服务端可信目录包含两个正式 SKU，客户端无法覆盖金额/币种/期限。
- [ ] 月付权益精确为 30 天，续费延长周期，取消不提前剥夺已付周期，过期后自动拒绝。
- [ ] 买断权益无到期时间。
- [ ] 支付成功前不发放权益；支付取消、失败不解锁；全额退款撤销对应权益。
- [ ] GUI、聊天快捷回复、自然语言、MCP、CLI 与本地 runtime 统一执行服务端权益门槛。
- [ ] 其他 Mini App 可用同一 manifest/bridge/API 声明商品和受保护能力。
- [ ] webhook 重放不会重复记账或重复延长权益。
- [ ] Rust/Node/前端类型检查及支付 E2E 全部通过，产出截图、视频、日志、JUnit/JSON 证据。
- [ ] PR 受保护合并到 canonical `main`，exact-main E2E 通过后发布严格更新版本。

## 开源优先调研记录

- Telegram Bot Payments / Stars：数字商品只授予服务端确认成功的权益，支付支持退款、条款和交易记录。
- Telegram Star subscriptions：当前周期固定 30 天，自动续费，取消后保持到当前周期结束。
- Telegram Desktop/TDLib 仅作为交互与状态机参考；Fabushi 不复制 GPL 源码，继续使用自研 Rust 核心和 provider adapter。
- Apple StoreKit 2 / Google Play Billing：数字能力在移动端使用平台内购，服务端绑定用户与 PaymentIntent 并校验 provider 商品标识。

## 变更面

- `mahayana-platform-worker` / `mahayana-pay-worker`：计划目录、支付意图、权益期限、查询、续费与退款。
- `mahayana-miniapp-protocol` / `mahayana-miniapp-bridge`：通用计划与付费门槛协议。
- 官方全球法布施 MCP/CLI/manifest/Marketplace package：声明并使用付费门槛。
- iOS / Android：月订阅、买断商品与恢复购买。
- E2E / CI / 发布：沙盒 provider、可视化旅程、exact-main release gate。

## 当前证据

- Base SHA：`6ae21cba7878d113ac2902df94d867e7d3b7cd34`
- 分支：`feat/fab-p0001-global-dharma-paywall`
- PR / CI / Release：待实现后填写。
