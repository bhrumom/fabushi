# Apple Sign In 实施计划 (App Store Review Guideline 4.8)

## 1. 目标描述
解决 App Store 拒绝通过的问题（Guideline 4.8 - Design - Login Services）。由于 App 提供了第三方服务登录（支付宝登录），按照苹果审核规则，必须同时提供“通过 Apple 登录”（Sign in with Apple）作为一个收集数据最少、保护隐私的等效登录机制。

## 2. 前期调研发现
- 当前的 App 使用 `tobias` 实现了支付宝登录，并在 `login_screen.dart` 中暴露了登录入口。
- 当前并未集成 `sign_in_with_apple`，由于 App 整体属于使用后端签发 JWT 的自定义认证逻辑（见 `AuthService`），我们需要在前端获取 Apple 凭证后与后端通信。

## 3. 拟更改列表 (Proposed Changes)

### Flutter 端改动
#### [MODIFY] pubspec.yaml
- 添加官方插件依赖 `sign_in_with_apple: ^6.1.1` 以提供标准的 Apple 登录功能和 UI。（版本将采用兼容的最新版本）

#### [MODIFY] lib/screens/login_screen.dart
- 引入 `sign_in_with_apple` 库。
- 在登录界面（和注册界面）包含支付宝登录的地方，添加标准的 `SignInWithAppleButton` 按钮。
- 出于合规和最佳实践，确保该按钮只在 Apple 平台（iOS/macOS）或其他支持平台正确显示。

#### [MODIFY] lib/services/auth_service.dart
- 添加 `appleLogin({required String identityToken, required String authorizationCode, String? email, String? givenName})` 方法，调用后端 API（例如: `/api/auth/apple-login`）。

#### [MODIFY] lib/models/auth_model.dart
- 添加暴露给 UI 的 `handleAppleLogin()` 方法处理具体交互逻辑：弹出原生 Apple 授权窗口、拿到 Token 后传递给 `AuthService`。最后保存用户信息并刷新状态。

#### [MODIFY] PRD/app_store_review_reply.md
- 在此审核回复文案中新增一条回复，说明我们已经接入了苹果建议的 "Sign in with Apple" 并在客户端上线，从而满足 Guideline 4.8 的要求。

---

> [!IMPORTANT]
> ## 需要用户确认的重要事项 (User Review Required)
> 
> 由于当前我们的 Flutter 前端依靠独立的后端来签发自定义的 Token (参看 `firebasePhoneLogin` 和 `alipayLogin` 的逻辑)，当用户通过 Apple 登录并获得 Apple 签发的 `identityToken` 时，我们需要将其发送到我们的服务器。
> 
> **请确认**：我们是否已经有一个类似于 `/api/auth/apple-login` 的后端接口？
> - **如果有**：请告知接口的具体路径以及它期望的传入参数（例如是否只需要 `identityToken`）。
> - **如果没有**：在前后端分离的架构中，必须先在后端利用相应的库（如 Node.js 的 `apple-signin-auth`）实现此验证接口并关联用户数据库。我们可以先在 Flutter 端把获取到的 Token 打印出来或者先按照某种规范写好请求代码。

## 4. 验证计划 (Verification Plan)
- **静态代码验证**：使用 `flutter analyze` 确保语法没有错误。
- **真机/模拟器测试**：因本地无法模拟后端接口，需通过运行 iOS 模拟器点击 Sign in with Apple，确认能弹出 iOS 原生的 Apple ID 统一登录页面。
- 如果没有真实的后台对应 Endpoint，验证时会看到发起请求后失败（预期内行为），但能证明前端鉴权与参数获取流程全部打通。
