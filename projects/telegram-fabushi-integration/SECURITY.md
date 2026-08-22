# Security Policy — Telegram → Fabushi 融合项目

安全设计基线见 `docs/13-安全威胁模型与隐私.md`。

## 高敏感域

以下改动默认需要安全专项审查：

- 身份、设备验证、认证 Session、密钥与 E2EE；
- Mini App bridge、signed init data 与权限撤销；
- Agent 工具调用、敏感权限和审计；
- 支付、Webhook、Ledger、退款与对账；
- 文件上传、媒体解析与外部 URL；
- 服务端管理权限、moderation 与 admin log。

## 合并要求

高敏感改动必须包含明确威胁、控制措施、失败路径和自动化验证。不得把密钥、Token、支付凭据或用户敏感数据写入仓库、测试快照或日志。

## 漏洞处理

具体私密报告渠道尚未由源计划指定，因此本文件不虚构邮箱或平台。项目接入正式安全渠道后，应在此补充报告入口、响应等级和披露策略。
