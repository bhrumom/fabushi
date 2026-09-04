# M6 频道、订阅、Topic 与管理能力

- **Project ID**：`FAB-P0001`
- **Project Key**：`TFI`
- **来源**：`source/full-plan/part-04.txt`、`source/full-plan/part-05.txt`、`docs/02-产品需求-PRD.md`
- **提出日期**：2026-09-04

## 持久化需求

1. 频道必须有独立的订阅者集合；订阅者可以接收广播、同步频道状态和分页读取成员，但不能因为订阅而获得发帖权。
2. Topic 必须有服务端状态、独立未读游标和独立草稿；关闭或隐藏的 Topic 不接受新消息。
3. 频道/群组管理操作必须由 Rust 核心按操作粒度校验；慢速模式、封禁/限制和管理员操作需要可审计。
4. 成员列表和管理日志必须使用有界分页；管理日志不得通过面向所有受众的广播事件泄漏，邀请 token 只能给有权管理员。
5. 广播事件受参与者、Owner 和频道订阅者 audience 控制；退出、封禁后必须撤销频道访问。

## 本轮实现边界

- 在 `native/mahayana-messaging` 的统一协议、状态机、服务和快照中实现上述语义。
- 在 Electron self-hosted client 暴露对应命令和事件接收面，继续使用同一 Rust 协议，不建立第二个聊天核心。
- 频道评论关联群、搜索分类、移动端 UI 和 packaged E2E 仍需按 M6/M7/M11 的独立验收矩阵继续闭环。

## 安全与兼容约束

- `CommunityState` 新字段使用兼容默认值，旧快照可读。
- `CommunityChanged` 的可重放 journal 副本清理邀请 token 与 admin log；管理员通过受保护的分页命令读取日志。
- 订阅、发帖、成员管理、Topic 管理和慢速模式均由服务端 Rust 状态机决定，客户端 UI 不能绕过。
