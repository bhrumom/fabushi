# 生产环境支付宝密钥设置指南

本文档将指导您如何在 Cloudflare 控制台中为您的生产环境 Worker (`fabushi`) 设置真实的支付宝应用密钥。

## 操作步骤

1.  **登录 Cloudflare 控制台**
    *   打开浏览器，访问 [Cloudflare Dashboard](https://dash.cloudflare.com/) 并登录您的账户。

2.  **导航至 Workers & Pages**
    *   在左侧导航栏中，找到并点击 **Workers & Pages**。

3.  **选择您的生产环境 Worker**
    *   在 Worker 列表中，找到并点击名为 `fabushi` 的 Worker。

4.  **进入设置 (Settings)**
    *   在 `fabushi` 的管理页面中，点击顶部的 **Settings** 选项卡。

5.  **配置环境变量 (Variables)**
    *   在 **Settings** 页面中，向下滚动找到 **Environment Variables** 部分。
    *   点击 **Add variable** 来添加或更新以下密钥。请注意：这些值是加密存储的，被称为 "Secrets"。

6.  **设置以下 Secrets**
    *   您需要为以下每个变量添加或更新其值。**请将下方“Value”列中的占位符文本替换为您从支付宝开放平台获取的真实信息。**

    | Variable name          | Value (请填入您的真实值)                    | Description          |
    | ---------------------- | ------------------------------------------- | -------------------- |
    | `ALIPAY_APP_ID`        | `在此处粘贴您的真实应用 APPID`              | 您的支付宝应用 APPID。 |
    | `ALIPAY_PRIVATE_KEY`   | `在此处粘贴您的应用私钥 (PKCS8 格式)`       | 请确保是完整的 PKCS8 格式私钥，而不是 PKCS1。 |
    | `ALIPAY_PUBLIC_KEY`    | `在此处粘贴您的支付宝公钥`                  | 从支付宝开放平台获取的支付宝公钥。 |
    | `ALIPAY_SANDBOX`       | `false`                                     | **重要**: 填入文本 `false` 以切换到生产环境。 |

    **如何添加/编辑:**
    *   在 **Variable name** 字段中输入变量名 (例如 `ALIPAY_APP_ID`)。
    *   在 **Value** 字段中粘贴对应的值。
    *   点击 **Encrypt** 按钮对该值进行加密。
    *   对上述所有变量重复此操作。

7.  **保存并部署**
    *   添加/更新完所有 Secrets 后，点击 **Save** 按钮。
    *   Cloudflare 会自动触发一次新的部署，以使新的环境变量生效。您可以在 `fabushi` Worker 的主页面查看部署状态。

部署成功后，您的应用将开始使用真实的支付宝密钥处理生产环境的支付请求。