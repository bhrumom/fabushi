# 支付宝 iOS 应用内网页登录方案

## 问题背景

App Store 审核拒绝 (Guideline 4.2.3(i))：应用要求用户安装支付宝 APP 才能登录。Apple 要求用户应能在**应用内**完成支付宝登录，不得依赖外部 APP。

Apple 建议使用 **ASWebAuthenticationSession**（Safari View Controller API），在应用内嵌入浏览器完成 OAuth 授权 —— 用户可在应用内查看 URL 和 SSL 证书，确认是合法页面。

## 当前流程分析

```
iOS 用户点击"支付宝登录"
  → login_screen.dart 调用 _handleAlipayLogin()
  → authModel.getAlipayLoginUrl(platform: 'ios')
  → 后端返回支付宝 OAuth URL
  → launchUrl(uri, mode: LaunchMode.externalApplication)  ← 跳出 App！
  → 打开外部浏览器/支付宝 APP
  → 回调到 mobile-callback 后端端点
  → 重定向回 App
```

**问题核心**：`LaunchMode.externalApplication` 会跳出应用，且 `tobias` SDK 会检查支付宝是否安装。

## 方案设计

在 iOS 平台上使用 Flutter 的 `url_launcher` 包的 `launchUrl` + `LaunchMode.inAppBrowserView`（底层即 `ASWebAuthenticationSession` / `SFSafariViewController`），在**应用内**打开支付宝 OAuth 授权页面，无需安装支付宝 APP。

> [!IMPORTANT]
> 此方案**仅修改 iOS 平台**的登录行为。macOS、Android、Web 平台保持不变。

### 核心改动

1. **iOS 平台智能判断**：通过 `AlipayService().isAlipayInstalled()` 检查设备是否安装了支付宝 APP。
2. **已安装支付宝**：保持 `LaunchMode.externalApplication` 唤起支付宝，快速登录。
3. **未安装支付宝**：使用 `LaunchMode.inAppBrowserView`（Safari View Controller API）提供内置登录回退机制，满足苹果审核要求。

## 实施方案

### 修改文件

---

#### [MODIFY] [login_screen.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/login_screen.dart)

**引入依赖**：
```dart
import '../services/alipay_service.dart';
```

**修改 `_handleAlipayLogin` 和 `_handleAlipayOneClickRegister` 方法**：

```diff
       final uri = Uri.parse(loginUrl);
+      
+      bool isInstalled = false;
+      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
+        try {
+          isInstalled = await AlipayService().isAlipayInstalled();
+        } catch (e) {
+          debugPrint('检查支付宝安装状态失败: $e');
+        }
+      }

-      if (await canLaunchUrl(uri)) {
-        await launchUrl(uri, mode: LaunchMode.externalApplication);
+      if (!kIsWeb && Platform.isIOS) {
+        if (isInstalled) {
+          await launchUrl(uri, mode: LaunchMode.externalApplication);
+        } else {
+          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
+        }
+      } else if (await canLaunchUrl(uri)) {
+        await launchUrl(uri, mode: LaunchMode.externalApplication);
       } else if (kIsWeb) {
         _platformService.openUrl(loginUrl, '_self');
       }
```

---

#### [MODIFY] [alipay-login-functions.js](file:///Users/gloriachan/Documents/fabushi/fabushi/web/alipay-login-functions.js)

**`generateAlipayLoginUrl` 函数**：确认 iOS 平台使用 `mobile-callback` 回调地址（已支持，无需修改回调逻辑）。

目前 `handleMobileAlipayCallback` 回调处理逻辑已经存在，会处理重定向回 App。只需确保 iOS 平台传入 `platform=ios` 参数。**此文件可能不需要实际修改**，视回调测试结果而定。

---

### 不需要修改的部分

- `alipay_auth_service.dart` — HTTP API 层无需改动
- `auth_model.dart` — 模型层无需改动
- `alipay_service.dart` (tobias SDK) — 保留但**iOS 登录流程不再走此路径**，仅用于 Android 支付

## 验证方案

### 自动化测试

项目现有测试文件在 `test/` 目录下，但无专门的支付宝登录测试。由于此改动涉及原生平台行为（`ASWebAuthenticationSession`），无法通过单元测试验证核心逻辑。

### 手动测试（需用户协助）

> [!CAUTION]
> 此功能需要在**真实 iOS 设备或模拟器**上测试，且需要有效的支付宝开发者配置。

1. **在 iOS 设备/模拟器上运行 App**
2. **进入登录页面，点击"支付宝登录"**
3. **验证行为**：
   - ✅ 应该在应用内弹出浏览器页面（Safari View Controller），显示支付宝 OAuth 授权页
   - ✅ 用户应能看到 URL 栏和 SSL 证书信息
   - ❌ 不应跳出应用
   - ❌ 不应提示安装支付宝 APP
4. **完成授权后**：验证回调能正确返回应用并完成登录
5. **验证其他平台**：确认 macOS、Android 登录行为未受影响

### 代码分析

```bash
# 使用 Dart 分析器检查代码
cd /Users/gloriachan/Documents/fabushi/fabushi
flutter analyze lib/screens/login_screen.dart
```
