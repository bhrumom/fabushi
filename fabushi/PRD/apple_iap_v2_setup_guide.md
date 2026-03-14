# App Store Connect - Apple IAP (v2) 与自动续期订阅配置指南

由于我们目前迁移到了 Apple 最新的 **App Store Server API v2**，并且采用了 **自动续期订阅 (Auto-Renewable Subscription)** 的模式来代替老旧的单次购买，设置步骤将会分为以下三大块：

1. **配置自动续期订阅产品** (App Store Connect)
2. **生成 API v2 所需的密钥** (App Store Connect)
3. **配置 Cloudflare Worker 的环境变量** (Wrangler / Cloudflare Dashboard)

---

## 第一部分：创建自动续期产品 (App Store Connect)

### 1. 创建订阅产品
1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)。
2. 进入 **我的 App** -> 选择 **法布施**。
3. 在左侧菜单栏向下滚动，找到 **App 内购买项目 (In-App Purchases)**，点击 **管理 (Manage)**。
4. 点击 **添加 (+)** 按钮，选择 **自动续期订阅 (Auto-Renewable Subscription)**。
5. 第一个弹窗会要求你填写 Reference Name (仅自己可见) 和 Product ID，你需要依次创建如下 3 个产品：
   - 引用名称: `Fabushi Monthly Membership` -> 产品 ID: `com.ombhrum.fabushi.membership.monthly`
   - 引用名称: `Fabushi Quarterly Membership` -> 产品 ID: `com.ombhrum.fabushi.membership.quarterly`
   - 引用名称: `Fabushi Yearly Membership` -> 产品 ID: `com.ombhrum.fabushi.membership.yearly`

### 2. 设置订阅群组 (Subscription Group)
（创建首个产品时 Apple 会提示你创建群组）
- 群组名称可以填写 `Fabushi Premium`（用户可见）。
- 将刚才创建的 3 个档位产品添加入此群组。它们处于同一群组内，用户购买高级别产品时 Apple 会自动计算升降级退款策略。

### 3. 配置每个产品的详情
点进每一个产品的详情页，分别配置以下内容：
1. **订阅时长 (Subscription Duration):** 分别选择 1 个月、3 个月、1 年。
2. **订阅价格 (Subscription Prices):** 分别设置基础价格 (如 21元 / 63元 / 252元)。
3. **App Store 本地化 (App Store Localization):** 
   - 语言: `简体中文`
   - 显示名称: `月度会员` / `季度会员` / `年度会员`
   - 描述: `解锁完整的法布施会员专属功能，持续学习和进步。`
4. **审核信息 (Review Information):** 
   - 截屏: 上传一张 App 内购买页面的截图（尺寸可以参照 1284x2778 像素）。
   - 审核备注: `这是解锁 App 高级功能的会员订阅选项。`

---

## 第二部分：生成与配置 Server API 密钥

在 v2 接口中，我们需要服务端调用 App Store Server API，因此需要一个专门的服务端身份。

### 1. 寻找你的 Issuer ID
1. 在 [App Store Connect](https://appstoreconnect.apple.com/) 的主界面，点击顶部的 **用户和访问 (Users and Access)**。
2. 选择 **集成 (Integrations)** 标签页。
3. 点击 **App Store Connect API**，在页面的上方你会看到类似 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` 的一串字符（老账号可能是 10 位字母数字，目前通常是一个 UUID）。那就是你的 **Issuer ID**。
   *(记下这串 Issuer ID)*

### 2. 创建 In-App Purchase Key (获取 Key ID 和 .p8 文件)
1. 在同样的 **App Store Connect API** 页面，找到 **密钥 (Keys)**，点击 **+ 添加**。
2. 名称填写：`Fabushi IAP Server Key`。
3. 访问权限 (Access) 下拉列表选择 -> **App 内购买项目接口 (In-App Purchase)**。（如果页面结构变了，选择拥有 `App Store Server API` 权限的选项）。
4. 保存后，列表里会多出一条记录。
5. 复制记录列表里的 **密钥 ID (Key ID)**（例如 `A1B2C3D4E5`）。*(记下这个 Key ID)*
6. 点击右侧的 **下载 API 密钥**。这会下载一个格式为 `AuthKey_A1B2C3D4E5.p8` 的文件。
   *(妥善保管这把 .p8 私钥文件，它只能下载一次！丢失了必须作废后重新建立)*

### 3. 获取你的 App 的 Bundle ID
对于 Flutter 项目，默认情况这在你在苹果官网创建 App 时就有，法布施的一般是 `com.ombhrum.fabushi`。*(记下这个 Bundle ID)*

---

## 第三部分：在 Cloudflare Worker 中配置环境变量设置

我们刚才获取到了 4 样东西，现在必须通过 Wrangler 将它们注入到 Cloudflare Worker 的 Secrets 里，否则 Apple IAP 验证接口会工作失败（报错 500）。

打开终端，进入项目的网页后端目录：
```bash
cd web/
```

然后依次执行以下 4 条命令。每次执行时，终端会停顿等你输入值，粘帖后回车即可：

**1. 配置 Bundle ID**
```bash
npx wrangler secret put APPLE_BUNDLE_ID
```
*(输入例如：`com.ombhrum.fabushi`)*

**2. 配置 Issuer ID**
```bash
npx wrangler secret put APPLE_ISSUER_ID
```
*(输入刚才在第二部分记下的 Issuer ID UUID)*

**3. 配置 Key ID**
```bash
npx wrangler secret put APPLE_KEY_ID
```
*(输入刚才在第二部分记下的 10 位字母数字的 Key ID)*

**4. 配置 P8 私钥内容**
```bash
npx wrangler secret put APPLE_PRIVATE_KEY
```
由于私钥包含换行符（长得像 `-----BEGIN PRIVATE KEY-----\nMIGHAg...`），很多时候直接粘帖在某些终端会失败。
建议的操作：**用文本编辑器（如 VSCode 或记事本）打开下载下来的 `.p8` 文件，全选复制。在弹出的输入提示处粘帖，然后回车**。

> 此配置仅修改了云端的 Worker。如果你在本地使用 `npm run dev` 测试后端，请在 `web/.dev.vars` 里也增加同样的配置：
> ```
> APPLE_BUNDLE_ID="com.ombhrum.fabushi"
> APPLE_ISSUER_ID="xxxxxxxx-xxxx-xxxx..."
> APPLE_KEY_ID="A1B2C3D4E5"
> APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGHAgEA... (由于在一行需要替换换行符为实际的 \n 或者不用修改直接起多行)"
> ```

---

## 验证与发布

1. 一旦密钥和环境变量配置完毕并且在 Cloudflare Worker 重新加载后，后端即准备就绪。
2. 请使用一个干净的 **[Sandbox (沙盒) 账号](https://developer.apple.com/apple-pay/sandbox-testing/)** 登录一台 iPhone 真机。
3. 在 App 内点击会员充值，会掉起沙盒环境支付页面，进行指纹/密码验证后，回到 App，App 屏幕底部应出现 "支付成功！会员已激活" 的提示。
4. Apple 产品创建部分需要你完成 App 其他内容开发后，发版时一并提交审核通过，这些订阅产品才能在线上环境被用户真实购买。
