# Tailscale 跨平台设备网格融合需求

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Captured: `2026-08-31`
- Upstream: `tailscale/tailscale`
- License: BSD-3-Clause

## 原始目标

将 Tailscale 项目的成熟设计与优势完整融合进 Fabushi 的正式设备控制架构，使同一 Fabushi 账号下安装并登录的桌面端、Android、iOS 设备都能被发现，并能从其他端或 AI 客户端调用该设备明确发布的控制能力。GitHub Actions Runner 使用既有测试账号安装/登录应用后，必须可被 `@fabushi test` 发现和调用，并作为持续验收环境。

## 工程解释

“完整融合”指能力级、架构级和质量级融合，而不是把整个 Tailscale 仓库无差别复制进 Fabushi。Tailscale 核心仓库包含 `tailscaled`、CLI、控制客户端、WireGuard 数据面、NAT 穿透与 DERP 路径等大量通用网络组件；其移动 GUI 并不全部位于该开源仓库。Fabushi 必须：

1. 保留 Tailscale BSD-3-Clause 来源与归属记录；
2. 学习并融合已验证的节点身份、控制面/数据面分离、网络映射、租约、路径迁移、直连优先/中继兜底、健康诊断和故障测试思想；
3. 复用 Fabushi 已有账号 OAuth、动态 MCP 工具目录、App MCP、Computer Use、secure input、审计与发布体系；
4. 不引入第二套账号体系、第二套远控授权模型或绕过平台权限的通道；
5. 对无法在所有平台等价实现的系统能力显式建模。例如 iOS 在应用被系统挂起后不能保证常驻 WebSocket，必须采用活动会话、系统后台任务/推送唤醒和明确在线状态，而不能伪造永久在线。

## 必须交付的能力

- 每台设备拥有持久、不可导出的节点身份；注册消息由节点密钥签名。
- 服务端仍以 Fabushi 账号作为发现与授权边界，同时验证节点签名并记录节点指纹。
- 设备目录返回协议版本、路径、节点指纹、设备标签、姿态与工具 schema 版本。
- 控制路径显式表示；首阶段保持经过官方 WSS 网关的加密中继，后续可增量加入直连候选而不改变工具合同。
- 设备重连、密钥轮换、租约过期、旧 socket、旧 generation 和重放请求全部 fail closed。
- Electron、Android、iOS 共享同一 `fabushi.app.*` 语义工具合同；桌面继续提供完整 Computer Use，移动端至少提供应用内语义控制和生命周期状态。
- Android 在用户允许的前提下通过前台服务维持受控在线；iOS 使用活动连接、后台任务/系统唤醒并准确报告可用性。
- GitHub Actions 对签名注册、账号隔离、路径状态、重连、移动端合同、打包应用和实时测试账号发现/调用提供证据。

## 上游研究结论

采用：

- `control/controlclient` 与 `netmap` 的期望状态/增量更新思想；
- `wgengine/magicsock` 的可变路径、直连优先和中继兜底模型；
- 节点密钥与设备身份分离于账号登录凭据的原则；
- 连接健康、端点变化、租约与故障注入测试方法；
- `tsnet` 的“把私有网络能力嵌入应用边界”思想。

不直接复制：

- Tailscale 托管控制平面；
- 与 Fabushi 产品无关的 VPN 路由、出口节点、DNS、子网路由和操作系统网络栈管理；
- 非开源移动/桌面 GUI 包装层；
- 会与 Fabushi OAuth、MCP 权限和应用商店约束冲突的常驻系统 VPN 行为。

这些“不复制”项不代表丢弃优点；对应的可靠性、安全性和路径思想由 Fabushi 自有设备网格合同承载。
