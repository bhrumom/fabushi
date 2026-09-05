# Rust Workspace 与模块边界

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-05
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

建议在现有 Fabushi workspace 中建立统一通信域，最终结构可按项目实际目录调整：

crates/
  fabushi-protocol/           # 所有协议类型、版本与编码
  fabushi-identity/           # 用户、设备、身份、联系人
  fabushi-crypto/             # 密钥、签名、E2EE 基础能力
  fabushi-transport/          # WebSocket/QUIC/HTTP fallback
  fabushi-sync/               # 多设备增量同步引擎
  fabushi-messaging/          # 消息状态机与业务逻辑
  fabushi-conversations/      # 私聊/群/频道/Topic
  fabushi-presence/           # 在线、输入、已读、最后上线
  fabushi-media/              # 上传、下载、缓存、缩略图
  fabushi-search/             # 本地/服务端搜索
  fabushi-notifications/      # 推送与通知事件
  fabushi-call-core/          # 通话会话与 WebRTC bridge
  fabushi-agent-network/      # Bot/Agent/Agent-to-Agent
  fabushi-miniapp-core/       # Mini App 权限与 bridge
  fabushi-pay-core/           # 订单、支付意图、商户协议
  fabushi-storage/            # SQLite/数据库抽象
  fabushi-client-sdk/         # 对 Electron/iOS/Android 暴露统一 API
  fabushi-testkit/            # 协议仿真、断网、延迟、乱序测试

services/
  identity-service/
  gateway-service/
  message-service/
  sync-service/
  presence-service/
  contact-service/
  group-service/
  channel-service/
  media-service/
  search-service/
  notification-service/
  call-signaling-service/
  agent-service/
  miniapp-service/
  payment-service/
  moderation-service/

apps/
  desktop-electron/
  ios/
  android/

协议定义：
  proto/ 或 protocol/
    common
    identity
    conversation
    message
    media
    sync
    call
    miniapp
    payment
    agent


============================================================

## 模块边界规则（项目管理补充）

- `fabushi-protocol` 只能定义协议/版本/编码，不承载 UI 逻辑。
- `fabushi-messaging` 负责消息状态机，不直接依赖 Electron/Swift/Kotlin UI。
- `fabushi-client-sdk` 是跨端公开门面；客户端不得绕过它重复实现消息业务状态机。
- `fabushi-agent-network` 复用 Participant/Conversation/Message，不建立第二套聊天模型。
- `fabushi-miniapp-core` 与 `fabushi-pay-core` 必须通过显式权限/意图对象与消息域交互。
- 每个新 crate/service 必须在 PR 中说明所属域、依赖方向和替代的旧模块。

## 2026-09-05 — MAINSAFE exact-head repair boundary

`TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001` is an Actions checkout-identity repair, not a Rust/workspace repair.

- No `Cargo.toml`, `Cargo.lock`, Rust crate, Rust test, generated binding, dependency version or workspace membership may change.
- `.github/scripts/assert-native-electron-canonical.sh` remains unchanged and continues to be the single canonical version assertion implementation.
- The only implementation/config surfaces are `.github/workflows/ci.yml` and `mobile/ios/project.yml CURRENT_PROJECT_VERSION 28 -> 29`; task-specific TFI records may accompany them.
- Any execution discovery that requires a Rust/Cargo/dependency change is a stop condition requiring a new Architecture decision rather than scope expansion.
