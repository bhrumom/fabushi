# 支付宝登录临时解决方案

## 问题

macOS平台支付宝登录失败，提示找不到 `flutter.ombhrum.com/api/auth/alipay/macos-callback`

## 原因

后端缺少 `/api/auth/alipay/macos-callback` 路由（返回404）

## 临时解决方案

已应用临时修复，macOS现在使用Web平台的回调方式。

### 修改内容

- 文件：`lib/screens/login_screen.dart`
- 修改：注释掉macOS平台特殊处理，使用默认Web回调

### 使用方法

1. **重新运行应用**
```bash
flutter run -d macos
```

2. **点击支付宝登录**
   - 会在浏览器中打开支付宝登录页面
   - 完成支付宝授权后，会跳转到Web回调页面
   - 需要手动复制回调URL中的参数

3. **Web回调处理**
   - 回调URL格式：`https://flutter.ombhrum.com/login.html?auth_code=xxx&state=xxx`
   - 前端会自动处理这个回调

## 永久解决方案

需要后端团队实现以下任一方案：

### 方案A：添加HTTP回调路由（简单）

在后端添加 `/api/auth/alipay/macos-callback` 路由：

```javascript
router.get('/api/auth/alipay/macos-callback', async (req, res) => {
  const { auth_code, state, app_id, source, scope } = req.query;
  
  try {
    // 1. 验证state参数
    // 2. 使用auth_code换取access_token
    // 3. 获取用户信息
    // 4. 创建或登录用户
    // 5. 生成JWT token
    
    // 重定向到自定义scheme，传递登录信息
    const params = new URLSearchParams({
      alipay_auth_code: auth_code,
      token: jwtToken,
      username: user.username,
      alipay_user_id: alipayUserId,
      alipay_nickname: alipayNickname,
      alipay_avatar: alipayAvatar,
      isNewUser: isNewUser.toString()
    });
    
    res.redirect(`globaldharma://alipay-callback?${params.toString()}`);
  } catch (error) {
    // 错误处理
    const errorParams = new URLSearchParams({
      error: error.code || 'UNKNOWN_ERROR',
      error_message: error.message || '支付宝登录失败'
    });
    res.redirect(`globaldharma://alipay-callback?${errorParams.toString()}`);
  }
});
```

### 方案B：使用自定义scheme（推荐）

修改 `/api/auth/alipay/login-url` 接口，当 `platform=macos` 时返回自定义scheme：

```javascript
let redirectUri;
if (platform === 'macos') {
  // macOS使用自定义scheme，由后端的macos-callback路由处理后重定向
  redirectUri = 'https://flutter.ombhrum.com/api/auth/alipay/macos-callback';
} else if (platform === 'web') {
  redirectUri = 'https://flutter.ombhrum.com/login.html';
} else {
  redirectUri = 'https://flutter.ombhrum.com/api/auth/alipay/callback';
}
```

## 测试步骤

### 当前临时方案测试

1. 运行应用：`flutter run -d macos`
2. 点击"支付宝登录"或"支付宝一键注册"
3. 在浏览器中完成支付宝授权
4. 观察是否能正常跳转和登录

### 永久方案测试（后端修复后）

1. 恢复 `login_screen.dart` 中的macOS平台代码
2. 运行应用
3. 点击支付宝登录
4. 验证自定义scheme回调是否正常工作

## 相关文件

- `lib/screens/login_screen.dart` - 前端登录逻辑
- `lib/services/alipay_auth_service.dart` - 支付宝认证服务
- `macos/Runner/Info.plist` - macOS URL Scheme配置
- `ALIPAY_MACOS_FIX.md` - 详细技术文档

## 注意事项

1. 临时方案可能需要用户手动操作
2. 建议尽快联系后端团队实现永久方案
3. 永久方案实现后，需要恢复前端代码的注释部分

## 联系后端

请将 `ALIPAY_MACOS_FIX.md` 文档发送给后端团队，说明需要添加的路由和逻辑。
