# Fabushi Pay

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-11
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

目标：Mini App、Bot、Agent、聊天内商品统一走 Fabushi Pay。

核心模型：
- Merchant
- Product
- Order
- PaymentIntent
- PaymentMethod
- Provider
- Refund
- Settlement
- Ledger
- WebhookEvent

统一支付流程：
1. Mini App/Bot/Agent 创建 Order
2. Fabushi Pay 创建 PaymentIntent
3. 根据平台/地区选择 Provider
4. 用户确认支付
5. Provider 返回结果
6. Payment Service 验签
7. Ledger 记账
8. 更新 Order
9. Webhook 通知商户
10. Chat/Mini App 收到统一支付结果事件

必须支持 Provider Adapter：
- Apple In-App Purchase / StoreKit（虚拟商品场景遵循平台规则）
- Google Play Billing（虚拟商品场景遵循平台规则）
- Stripe 等外部支付渠道（适用场景）
- 地区支付渠道扩展

虚拟商品：
- Credits/Stars 类平台余额（如启用）
- 数字内容
- Mini App 虚拟服务
- Bot/Agent 服务

需要提前设计：
- 平台规则
- 税务/退款
- 余额监管风险
- KYC/KYB（如进入商户结算）
- 对账
- 风控

重要原则：
支付系统不要和聊天 UI 直接耦合；聊天只消费 PaymentIntent/PaymentResult 事件。


============================================================