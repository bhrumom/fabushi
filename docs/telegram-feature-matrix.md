# Telegram 全平台功能验收矩阵

本文件是面向产品和测试的总表；机器可读的逐项状态位于 `native/telegram-core/src/feature.rs`。状态含义：

- `Planned`：已进入范围，尚未定义完整 Rust 合约。
- `ContractDefined`：类型或边界已定义，但功能闭环尚未完成。
- `CorePartial`：Rust 领域核心已有部分可测试行为，不代表协议/UI 已完成。
- `Implemented`：协议、存储、UI、全平台和异常路径均已验收。

目前没有任何条目被标记为 `Implemented`，避免把本轮架构骨架误报为全功能完成。

| 功能域 | 必须覆盖的能力 | Android | iOS | macOS | Windows | Linux | Web | 当前结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 账号与授权 | 手机号、验证码、二维码、2FA、恢复、多账号、资料、设备会话、注销/导出 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 会话 | 私聊、Saved Messages、Secret Chat、归档、置顶、文件夹、草稿、自动删除、输入状态 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | CorePartial |
| 消息 | 富文本、回复/引用、转发、编辑、删除、定时、静默、受保护、相册、反应、投票、翻译 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | CorePartial |
| 媒体 | 图片、视频、文件、音频、语音、圆形视频、Sticker/Emoji、GIF、流式播放、下载管理、编辑 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 群组与频道 | 群、超级群、频道、Forum/Topic、管理员、审核、成员、邀请链接、统计 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 通话与直播 | 语音、视频、群组通话、直播、屏幕共享、设备切换、弱网恢复 | 必须 | 必须 | 必须 | 必须 | 必须 | 能力降级 | 计划 |
| Stories | 发布、查看、转发、回复、反应、隐私、精选、过期和下载 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 搜索与发现 | 全局/会话/媒体搜索、联系人、附近、Hashtag、公开帖子 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| Bot 与 Mini App | Bot 对话、Inline、键盘、命令、Mini App、游戏、Business Bot | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 支付与身份 | Invoice、支付提供商、Stars、Giveaway、Passport | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 合约/计划 |
| 安全与隐私 | 本地锁、生物识别、隐私规则、拉黑/举报、Secret Chat E2E、本地加密 | 必须 | 必须 | 必须 | 必须 | 必须 | 能力降级 | 合约/计划 |
| 通知 | Push、每会话通知、声音、Badge、快捷回复、通知动作 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | CorePartial/计划 |
| 外观与本地化 | 主题、壁纸、字体、聊天设置、语言、RTL、日期/数字格式 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 计划 |
| 无障碍 | 屏幕阅读器、动态字体、高对比度、减少动画、键盘导航 | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 计划 |
| 平台集成 | 分享/扩展、Deep Link、Widget、后台任务、托盘、全局快捷键、PWA | 必须 | 必须 | 必须 | 必须 | 必须 | 必须 | 计划 |

## 当前 Rust 消息核心已经覆盖

- 稳定的 `ChatId`、`MessageId`、`UserId` 与幂等 `ClientRequestId`。
- Private、Basic Group、Supergroup、Channel、Secret、Saved Messages 会话类型。
- 文本实体、文件、照片、视频、动画、音频、语音、圆形视频、文档、贴纸、投票、联系人、位置、场所、Dice、Story、Invoice 和 Service Message 数据模型。
- 本地 pending 消息映射到服务端 ID，失败状态和可重试信息。
- 编辑、逻辑删除、已读游标和置顶事件。
- command/event JSON 合约，可供 FFI、WASM、持久化日志和多端回放共用。
- 授权状态机已覆盖参数初始化、手机号、二维码、验证码、注册、二步验证密码、恢复、登出与远端权威状态更新。
- XChaCha20-Poly1305 加密 SQLite 快照、事件日志和消息表；事件和快照在一个事务内提交，支持 revision 冲突检测和错误 key 拒绝。
- 消息搜索使用 HMAC-SHA256 盲索引，不把正文或搜索 token 明文写入 SQLite；支持中英文、多词交集、会话过滤、编辑/删除和 schema v1→v2 迁移。
- C/JSON ABI 与 Flutter 原生服务入口；临时 client 和持久化 client 均有独立状态，持久化 client 已通过关闭/重开恢复测试。
- 原生 Rust TL 基础编解码已覆盖整数、浮点、Bool、bytes/string、vector、对齐、截断和资源上限防护。
- MTProto Full、Abridged、Intermediate、Padded Intermediate 传输帧已覆盖初始化标记、分包等待、序号、CRC 和长度上限。
- auth-key 握手密码学与状态机已覆盖 req_pq_multi、resPQ、PQ 分解、受信 RSA 指纹、server_DH、client_DH、dh_gen_ok/retry/fail、auth key 和 server salt 派生。
- Native TCP 网络层已覆盖官方 bootstrap DC、IPv4/IPv6/端口候选回退、连接/读写超时、分片读取重组和 plaintext 信封交换；生产 DC2 已完成纯 Rust `dh_gen_ok` 以及 MTProto 2.0 加密 ping/pong 实网验收。
- C/JSON 运行时可通过 `telegram.bootstrapTransport` 建立并保留已认证会话，且只在加密往返验证通过后报告就绪；状态只暴露 auth-key ID，密钥本体留在 Rust 内存并在释放时清零。
- 通用加密 RPC 已覆盖 `rpc_result`/直接 service result、请求关联、容器、确认和 bad salt 重试；生产 DC2 的 `get_future_salts` 已完成实网验收。Layer 227 的连接初始化、发送验证码和验证码登录请求已有字节级合约，实登需要产品自有 `api_id/api_hash`。
- 手机号认证合约现已覆盖全部当前验证码发送类型、验证码登录、新号码注册、RPC 错误和 SRP 两步验证；Flutter 有对应状态界面，密码派生材料在 Rust 中清零。`updates.getState/getDifference` 及更新游标已进入运行时。
- 数据中心目录已覆盖 `help.getConfig` 的主/媒体/CDN、IPv4/IPv6 端点选择；RPC 错误路由已区分主 DC 迁移、文件 DC 重试、Flood Wait、重新授权和瞬态重试。
- 媒体传输状态机已覆盖优先级/FIFO、并发槽、连续分片、暂停恢复、断点续传、可重试失败和 SHA-256 完整性检查。
- WebAssembly client 已真实构建并经 Node 加载生成的浏览器 glue，完成状态查询和授权命令端到端验证；IndexedDB 加密仍未接入。
- Flutter 好友列表和私聊界面已直接消费 Rust command/event 状态：真实最后消息/时间替换占位数据，好友点击不再显示“下一步接入”，发送消息进入 Rust pending 队列。
- Android arm64-v8a、armeabi-v7a、x86_64 三个运行库均已实际构建并核验六个 FFI 符号；iOS、macOS 与 Web 也已有实际产物验证，Linux/Windows 构建接线纳入跨平台 CI。
- Android/iOS/macOS/Windows/Linux 原生客户端使用系统安全存储托管 256 位数据库密钥，并由 Rust 打开加密 SQLite；Web 仍明确降级为临时状态。

## 尚未完成的关键闭环

- 已接通真实 Telegram TCP、auth-key、加密 ping/pong 和 service RPC；连接初始化与手机号/验证码/SRP/注册流程已经实现，但真实账号端到端验收仍需产品 `api_id/api_hash` 和测试号码。当前 Flutter 发送仍会如实停留在 pending，未伪造服务端确认。
- TL 基础编解码、MTProto transport frame、消息加密、授权状态机、auth-key 握手、native socket I/O、通用 RPC 收发和数据中心迁移路由已实现；WebSocket transport、完整 difference 对象解析、持续更新循环与授权密钥恢复尚未接入。
- 加密快照、事件日志、消息表和盲索引搜索已实现；媒体索引和离线发送调度仍未完成。
- 尚未实现上传下载、媒体处理、VoIP、Stories、群/频道管理和 Secret Chat 加密。
- 六个平台运行库打包入口已经建立，但系统通知、后台任务、分享扩展、通话等平台专属适配和全功能端到端验收尚未完成。

这些缺口会按 `telegram-rust-migration.md` 的阶段顺序继续关闭。
