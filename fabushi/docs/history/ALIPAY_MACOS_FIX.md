# 支付宝 macOS 登录问题修复

## 问题描述

支付宝登录在macOS平台失败，错误信息：
```
找不到 flutter.ombhrum.com 的网页
https://flutter.ombhrum.com/api/auth/alipay/macos-callback?auth_code=...
```

## 问题原因

后端在生成支付宝授权URL时，为macOS平台设置的回调地址是：
```
https://flutter.ombhrum.com/api/auth/alipay/macos-callback
```

但是：
1. 这个路由在后端不存在（返回404）
2. macOS应该使用自定义scheme回调：`globaldharma://`

## 解决方案

### 方案1：修改后端（推荐）

后端需要在 `/api/auth/alipay/login-url` 接口中，当 `platform=macos` 时，返回自定义scheme回调URL：

```javascript
// 后端代码示例
if (platform === 'macos') {
  redirectUri = 'globaldharma://alipay-callback';
} else if (platform === 'web') {
  redirectUri = 'https://flutter.ombhrum.com/login.html';
} else {
  redirectUri = 'https://flutter.ombhrum.com/api/auth/alipay/callback';
}
```

### 方案2：添加后端路由

如果必须使用HTTP回调，需要在后端添加 `/api/auth/alipay/macos-callback` 路由：

```javascript
// 处理macOS支付宝回调
app.get('/api/auth/alipay/macos-callback', async (req, res) => {
  const { auth_code, state } = req.query;
  
  // 验证state
  // 使用auth_code换取access_token
  // 获取用户信息
  // 生成JWT token
  
  // 重定向到自定义scheme
  const params = new URLSearchParams({
    alipay_auth_code: auth_code,
    token: jwtToken,
    username: username,
    // ... 其他参数
  });
  
  res.redirect(`globaldharma://alipay-callback?${params.toString()}`);
});
```

## 当前配置

### macOS Info.plist
已正确配置自定义scheme：
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>globaldharma</string>
</array>
```

### 前端代码
已正确监听自定义scheme回调：
```dart
// lib/screens/login_screen.dart
Future<void> _handleMacOSAlipayCallback(String url) async {
  // 解析 globaldharma:// URL
  // 提取参数并处理登录
}
```

## 测试步骤

1. 修改后端代码
2. 重新部署后端
3. 在macOS上测试支付宝登录
4. 验证回调是否正确处理

## 临时解决方案

在后端修复之前，可以暂时使用Web平台的支付宝登录（在浏览器中打开应用）。

## 相关文件

- 前端：`lib/screens/login_screen.dart`
- 前端：`lib/services/alipay_auth_service.dart`
- 配置：`macos/Runner/Info.plist`
- 后端：需要添加 `/api/auth/alipay/macos-callback` 路由

## 联系方式

如需后端支持，请联系后端开发团队。
