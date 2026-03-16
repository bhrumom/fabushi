# Apple IAP 产品无法加载分析与解决计划

## 发现的问题
在测试 Flutter 应用时，遇到了苹果内购产品列表加载数量为 0，并且由于 `App Store Connect` 的配置处于 `1.0 Rejected` 或内购项尚未就绪导致的问题。从最新的 App Store Connect 截图信息来看，导致无法获取 IAP (`monthly`, `Quarterly`, `Annual`) 的原因确认与应用审核被拒、测试账号信息未填等直接挂钩。

## 问题原因深度分析

基于第一性原理，我们需要以下条件全部成立，沙盒（Sandbox）环境才能从 Apple 服务器成功获取到商品列表：
1. **Bundle ID 对应且一致**：App 的 Bundle ID 必须与添加 IAP 的那个应用的 Bundle ID 相同。
2. **付费应用协议已签署**：Apple 开发者账号中的“付费应用协议(Paid Applications Agreement)”必须在生效状态（Active）。
3. **商品状态为准备就绪**：被查询的 IAP 商品（Product ID）在 App Store Connect 中的状态必须是 `Ready to Submit`（准备提交）、`Approved`（已批准）或者即使正在审核，也不要是 `Metadata Missing`（缺少元数据）或 `Developer Action Needed`（需要开发人员操作）。
4. **测试环境沙盒登入**：设备上的“设置 -> App Store -> 沙盒账户”必须登录测试 Apple ID 且不能登出。

**结合截图的具体情况**：
- **版本被拒（1.0 Rejected）导致连带退回**：App 的 `1.0` 版本因为某种原因被拒了。当你首次通过发布新版本来一并提审这些新建立的内购项时，如果 App 本身被拒，这些挂靠在上面的内购项一般也会变为“需要开发人员操作（Developer Action Needed）” 或“退回”。
- **测试登录凭证缺失**：从截图下方看到，App Review Information（App 审核信息）中的 **Sign-in Information（登录信息）** 没有任何勾选或填写内容！因为应用内的“开通会员页面（MembershipScreen）”拦截了未登录用户，审核员如果拿不到测试账号密码，他们就无法测试充值流程，必然会直接将你的 App **拒绝**。

## 解决计划与接下来的任务

1. **查看苹果的拒绝理由：** 点击状态 `1.0 Rejected` 或前往被拒的消息中心，确认苹果具体给出的拒绝原因。一般情况下，补充缺少的信息或修改后重新提交就可解决。
2. **修复 App Review Information：** 勾选并填写 `Sign-in Information` 中的用户名和密码（你需要手边先注册一个随时可以登录进入主界面的测试账号用来应付审核团队）。
3. **修复 IAP 商品状态：** 前往 App Store Connect 侧边栏菜单下的 `App 内购买项目`（In-App Purchases），依次点开 `monthly`、`Quarterly`、`Annual`，检查它们是否有发红光、提示“需要开发人员操作”、“缺少本地化”、“缺少截图”等，将其修改完善直至状态重新变为“准备提交（Ready to Submit）”。
4. **重新提交 (Update Review)：** 修改完且补充信息后，利用页面的 `Update Review` 按键，或者在回复消息中跟审核员说明“增加了你们需要的测试账号”，重新将应用投入审核队列。只要 IAP 商品回到 Ready to Submit / Pending 的健康状态，我们在开发真机上的沙盒测试就能成功拉取（数量>0）。

---
**状态**：等待用户进行上述 App Store Connect 配置并更新，暂不需要在项目代码层面修改逻辑。
