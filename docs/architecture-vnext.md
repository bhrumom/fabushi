# Fabushi vNext 架构蓝图

## 1. 为什么现在就该大改

Fabushi 现在还没有正式上线到用户层，这正是做结构性重构的最佳窗口。

当前仓库已经同时承载：

- Flutter 客户端
- Cloudflare Worker API / D1 / KV / R2 / Durable Objects
- 官网前端 monorepo
- 较重的 CI / CD / GitHub Release / TestFlight 链路

这类系统如果继续按“哪坏修哪”推进，短期能亮绿，长期会越来越难改、越来越难测、越来越难发。

因此 vNext 的目标不是继续做补丁式收口，而是先把系统定成一个适合未来 2-3 年演进的形态，再让 CI/CD 去验证这个形态。

## 2. 总体判断

Fabushi 不适合现在就拆成微服务。

当前阶段最优解不是“很多服务”，而是：

**一个边界清晰的模块化单体（modular monolith） + 多端应用分仓级目录隔离 + 契约先行的数据与发布体系。**

这更符合大厂在 0->1 或 1->10 阶段的常见做法：

- 先把领域边界、模块边界、数据边界、发布边界理顺
- 把跨模块调用和发布流程规范化
- 只有当某个模块在吞吐、团队、部署频率上真的独立到值得拆服务时，才做服务化

## 3. vNext 北极星目标

### 3.1 产品层

- 用户身份以 `users.id` 为唯一运行时主键
- `username` / `nickname` / `email` / `phone` 全部降为属性，不再承担系统身份主键职责
- 同一用户在移动端、Web、支付绑定、评论、修行记录、社交关系里都只认同一个 `user_id`

### 3.2 代码层

- 客户端、官网、后端、领域模型、接口契约分层清晰
- 业务逻辑不再散落在 handler、widget、workflow 和一次性脚本里
- 任何重要业务规则都必须能在代码中找到唯一归属层

### 3.3 数据层

- D1 schema 以“前向兼容迁移”为唯一演进方式
- 不再允许“schema 文件是新的、线上库还是旧的、代码又按新的来读写”这种漂移
- 每一条 migration 都必须可在真实旧库上安全执行

### 3.4 交付层

- CI 验证模块边界、契约和可构建性
- CD 只做环境部署与环境验收，不再替代结构性测试
- 发布链只放行已经在 PR 阶段通过结构化验证的代码

### 3.5 大乘 CLI 统一能力层

App、桌面端、CLI 和 Web 使用同一组 `mahayana.*` JSON 命令：

```text
mahayana CLI ──────────┐
Flutter native ──C ABI─┼── 内置 Mahayana Runtime ── Codex core / mini-app / Telegram
                       │              │
Browser ───────WASM────┘              └── 大乘 Responses 模型接口 / 产品 API
```

- 原生长期 ABI 是 `mahayana_runtime_create/execute/receive/interrupt/
  resolve_approval/close`；命令与流式事件保持稳定 JSON 契约。
- 桌面端通过 Codex app-server client 在同一进程内运行上游 Codex core，
  不启动 `codex` 子进程，也不连接云端 Agent。
- 软件只使用支付宝/大乘软件账号。产品会话作为大乘 Responses provider 的
  内存凭据，不写入 Codex `auth.json`，也不出现 OpenAI 登录入口。
- iOS/Android 在应用进程内运行受限 Agent 与 Responses 模型适配器；它们不
  暴露 shell、任意进程、原生 Git 或沙箱外文件系统。
- 浏览器加载 `mahayana-web` WebAssembly，使用 Browser Fetch 直接请求模型
  provider；`/api/mahayana/execute` 云端 Agent 命令网关不存在。
- macOS、Linux、Windows 安装包携带 `mahayana` 和
  `libmahayana_runtime`，Codex core 直接链接进 Runtime，没有单独的 Codex
  可执行文件或旧 `mahayana-wrapper` 代理。
- 写操作在 MCP 层要求显式确认；任何 CLI/MCP 输出不得回显 token、授权码等
  凭据。

## 4. 目标仓库结构

建议逐步重构为：

```text
apps/
  mobile/              # Flutter App
  api-worker/          # Cloudflare Worker API
  official-site/       # 官网 Next.js

packages/
  contracts/           # API schema、DTO、错误码、事件契约
  domain/              # 纯业务规则、值对象、领域服务、领域错误
  shared-config/       # lint、tsconfig、build config、脚本模板

infra/
  migrations/          # D1 migrations
  workflows/           # CI/CD 设计文档与辅助脚本说明
  release/             # release manifest / 发布资产说明

docs/
  architecture-vnext.md
  adr/
```

如果当前不方便一次性移动目录，可以先保持现有目录不动，但按上面的目标结构逐步迁移：

- `fabushi/` 对齐到 `apps/mobile/`
- `fabushi/web/` 对齐到 `apps/api-worker/`
- `frontend/` 对齐到 `apps/official-site/`
- 把共享契约和纯业务规则逐步抽到 `packages/`

## 5. 后端目标架构

Worker 侧不要继续让 handler 直接同时承担：

- 路由解析
- 参数校验
- 认证
- 业务规则
- SQL 拼装
- 响应序列化

vNext 建议拆成五层：

### 5.1 Interface 层

职责：

- HTTP route
- request parsing
- auth context 注入
- response mapping

要求：

- 不写业务规则
- 不直接写复杂 SQL
- 不决定事务边界

### 5.2 Application 层

职责：

- use case 编排
- 权限判定
- 事务边界
- 跨 repository 协调

例如：

- `UpdateProfileUseCase`
- `CreateMeditationGroupUseCase`
- `ReviewJoinRequestUseCase`

### 5.3 Domain 层

职责：

- 纯业务规则
- 领域对象
- 领域约束
- 领域错误

例如：

- Owner 不能被自动清退
- Join request 审核权只属于 group owner
- Profile display name 与 system identity 分离

### 5.4 Infrastructure 层

职责：

- D1 repository
- KV / R2 / Email adapter
- 第三方登录 / 支付 adapter

要求：

- SQL 只在 repository 中集中出现
- 外部 API 只在 adapter 中出现
- 上层只依赖接口，不直接依赖 wrangler / D1 细节

### 5.5 Contract 层

职责：

- DTO
- error code
- response envelope
- auth payload schema

要求：

- 客户端、官网、Worker 共用同一份契约定义
- 任何 breaking change 必须先改契约，再改实现

## 6. 数据架构原则

### 6.1 身份模型

唯一主键：

- `users.id`

降级为属性：

- `username`
- `nickname`
- `email`
- `phone_number`
- `alipay_user_id`
- `wechat_openid`
- `firebase_uid`
- `apple_user_id`

原则：

- 所有关联表最终都要有 `user_id`
- `username` 仅保留兼容、展示、搜索用途
- 任何“改用户名”都不应再引发系统级身份迁移

### 6.2 schema 演进

规则：

- `schema.sql` / `schema_v2.sql` 只描述新库的目标形态
- 真正决定线上演进的是 `migrations/`
- migration 必须按“最旧仍存活库”来写，而不是按本地最新 schema 幻觉来写

### 6.3 migration 规范

每条 migration 默认必须满足：

- 可重复理解
- 可在真实旧库执行
- 失败时能明确看出是权限、SQL 还是旧结构不兼容
- 复杂重建型 migration 必须附带对应 guardrail

## 7. Flutter 客户端目标架构

移动端当前依赖很多，技术栈也偏混合。vNext 不建议继续叠新的状态管理范式。

建议统一成：

- 表现层：feature-first 页面/组件
- 状态层：单一主状态管理方案
- 领域层：纯业务模型与 use case
- 数据层：repository + remote/local datasource

建议路线：

- 保留 `Bloc` 作为主状态管理，逐步退出混用的 `Provider` / 零散 service locator 风格
- 每个 feature 都按以下结构收口：

```text
lib/features/profile/
  presentation/
  application/
  domain/
  data/
```

核心要求：

- UI 不直接拼后端字段兼容逻辑
- 页面不直接调用底层 service 写复杂流程
- 登录、资料编辑、共修小组、会员支付都改成 use case 驱动

## 8. 官网前端目标架构

官网不应继续和主产品后端逻辑强耦合。

官网目标：

- 只负责品牌、下载、说明、转化、FAQ、隐私与公开入口
- 不承担移动端业务兼容层责任
- 不跟 Worker 的内部实现细节耦合

建议：

- 官网只依赖 `packages/contracts` 里少量公开 DTO 或公开配置
- 官网自己的内容、SEO、页面生成和多端转化保持独立发布节奏
- 官网 CI 与主产品 CI 分开计时、分开失败域、分开缓存

## 9. 认证与账号体系目标

vNext 统一策略：

- token 只认 `userId` 为主
- `username` 只作兼容回退，不再作为未来新 token 的主身份载荷
- 第三方登录与绑定全部归入统一的 identity 模块

建议形成独立上下文：

- `Identity`
- `Account`
- `Membership`
- `Meditation`
- `Social`

这样后面不论支付宝、微信、Apple、Firebase 还是邮箱/手机号，都只是 identity provider，不再各自散落成多条半闭环逻辑。

## 10. CI/CD 应该怎么服务新架构

顺序必须反过来：

**先有架构边界，再有 CI/CD 边界。**

### 10.1 PR CI 分四层

#### A. Fast Checks

- lint
- format
- typecheck
- basic unit tests

目标：3-8 分钟内给出首轮反馈

#### B. Module Checks

- mobile feature tests
- worker application/domain tests
- frontend build/typecheck

目标：按模块失败，不互相污染

#### C. Contract Checks

- API contract snapshot
- auth token contract
- migration guardrails
- schema drift checks

目标：在 PR 阶段卡掉“代码和数据结构不一致”

#### D. Release Simulation

- worker dry-run bundle
- mobile package config bootstrap
- staging E2E script validation

目标：验证发布入口仍存在，但不在 PR 阶段做全量重部署

### 10.2 Mainline CD 分三层

#### Stage 1: Staging Deploy

- apply D1 migrations
- deploy worker
- run staging smoke
- run contract E2E

#### Stage 2: Production Promote

- only if staging gates pass
- production deploy
- production smoke

#### Stage 3: Release Publish

- GitHub Release
- package build
- TestFlight evidence
- release manifest

### 10.3 核心原则

- PR 阶段负责“结构正确”
- CD 阶段负责“环境可运行”
- Release 阶段负责“交付可追溯”

不要再让 CD 去发现本应在 PR 阶段就暴露的 schema / contract / ownership 问题。

## 11. 推荐实施顺序

### Phase 0: 先冻结目标

本阶段产出：

- 本文档
- ADR 列表
- 统一目录迁移计划
- 身份模型与 D1 演进原则

### Phase 1: 先打地基

优先做：

- `users.id` 成为全系统唯一身份主键
- 认证、资料、第三方绑定全部切到 `user_id` 主路径
- migration 体系稳定化
- contract 层抽出

### Phase 2: 后端分层

优先做：

- Worker router / use case / repository 分层
- 把高风险 handler 先拆掉：
  - auth
  - profile
  - meditation groups
  - membership/payment

### Phase 3: 客户端 feature-first 化

优先做：

- profile
- auth
- meditation groups
- membership

### Phase 4: CI/CD 重排

优先做：

- 按模块拆 job
- 把 contract checks 提前到 PR
- 把 CD 收敛成真正的 deploy/promotion gate

### Phase 5: 官网与产品边界彻底切开

优先做：

- 官网独立内容与发布节奏
- 官网只依赖公开契约，不再依赖内部实现偶然性

## 12. 不建议继续做的事

- 不建议继续把复杂业务规则堆进 Worker handler
- 不建议继续让 `username` 承担运行时主键
- 不建议继续在客户端页面里写大量后端兼容逻辑
- 不建议继续让 CI/CD 充当架构缺陷探测器
- 不建议现在就拆微服务

## 13. 这套设计对应到当前仓库的结论

如果按“大厂式、未上线前可以大改”的标准，我建议 Fabushi 接下来用下面的主线推进：

1. 先确立 vNext 架构与 ADR，不再按零散补丁主导方向
2. 先把身份模型、D1、契约层收正
3. 再拆 Worker 的业务分层
4. 再做移动端 feature-first 重构
5. 最后把 CI/CD 改成对新架构负责的验证系统

也就是说，**接下来不是“先把所有 CI/CD 修绿，再谈架构”，而是“先确定架构，再让 CI/CD 逐步对齐这个架构”。**

这才是当前阶段最值得做、也最不容易以后返工的路线。

## 14. 小程序 Runtime 内核边界

Fabushi 小程序宿主能力不要继续演化成一组零散 FFI 函数。目标形态应学习 TDLib 的边界设计：

```text
Flutter / MiniApp UI
  ↓
FabushiMiniApp.invoke(json)
  ↓
Dart Host Bridge
  ↓
Rust FabushiRuntime
  ↓
Capability Dispatcher
  ↓
HTTP / UDP / File / Policy / Audit / Queue
  ↓
Runtime Updates
  ↓
Flutter / MiniApp UI render
```

Rust runtime 是客户端能力内核，不是 UI 库。UI 层只负责展示、收集用户输入和订阅 updates；网络、文件、权限、重试、回执、审计和本地一致性应逐步进入 runtime。

当前 runtime ABI 应保留旧函数以兼容已存在调用：

- `fabushi_runtime_http_fetch_json`
- `fabushi_runtime_udp_open_json`
- `fabushi_runtime_udp_send_json`
- `fabushi_runtime_udp_broadcast_json`
- `fabushi_runtime_udp_close_json`

新能力必须优先走统一 JSON ABI：

- `fabushi_runtime_create_client()`
- `fabushi_runtime_send(client_id, request_json)`
- `fabushi_runtime_receive(client_id, timeout_seconds)`
- `fabushi_runtime_execute(request_json)`
- `fabushi_runtime_close(client_id)`

统一 request 使用 `@type` 标识能力，`@extra` 用于请求和响应关联：

```json
{
  "@type": "network.http.fetch",
  "@extra": "req_001",
  "url": "https://api.ombhrum.com/api/global-dharma/send",
  "method": "POST",
  "body": "..."
}
```

runtime 返回 typed response 或主动 update：

```json
{
  "@type": "network.http.response",
  "@extra": "req_001",
  "statusCode": 200,
  "bodyBytes": 1234
}
```

```json
{
  "@type": "updateRuntimeRequestAccepted",
  "clientId": 1,
  "requestId": 42,
  "@extra": "req_001"
}
```

后续迁移原则：

- 新 runtime 能力只加 dispatcher method，不新增一组专用 FFI symbol。
- UI 不直接维护发送成功、回执、重试和队列状态，改为订阅 runtime updates。
- Global Dharma 发送链路最终应由 runtime 产出 `updateGlobalDharmaDeliveryStarted`、`updateGlobalDharmaPacketSent`、`updateGlobalDharmaReceiptReceived`、`updateGlobalDharmaDeliveryFailed`。
- 文件、素材包、离线包和回执文件应进入统一 file state/update 模型，不由页面单独管理。
- 授权和能力协商应收敛为状态机，例如 `authorizationStateWaitCapabilities`、`authorizationStateWaitUserConsent`、`authorizationStateReady`、`authorizationStateDenied`。
