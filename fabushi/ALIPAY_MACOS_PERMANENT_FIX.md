# 支付宝 macOS 登录永久修复方案

## ✅ 修复完成

已成功添加 `/api/auth/alipay/macos-callback` 路由，支持macOS平台支付宝登录。

## 🔧 修复内容

### 1. 后端修复

#### 添加路由 (`web/src/router.js`)
```javascript
if (pathname === '/api/auth/alipay/macos-callback' && method === 'GET') 
  return await handleMacOSAlipayCallback(request, env);
```

#### 导出处理函数 (`web/src/handlers/thirdparty.js`)
```javascript
export async function handleMacOSAlipayCallback(request, env) {
  const { handleMacOSAlipayCallback } = await import('../../alipay-login-functions.js');
  return await handleMacOSAlipayCallback(request, env);
}
```

#### 回调处理逻辑 (`web/alipay-login-functions.js`)
- 接收支付宝回调参数 (auth_code, state)
- 验证state参数
- 获取支付宝用户信息
- 检查用户是否已注册
- 重定向到自定义scheme: `globaldharma://`

### 2. 前端修复

#### 恢复macOS平台代码 (`lib/screens/login_screen.dart`)
```dart
String? platform;
if (!kIsWeb && Platform.isMacOS) {
  platform = 'macos';
}
```

#### macOS URL Scheme配置 (`macos/Runner/Info.plist`)
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>globaldharma</string>
</array>
```

## 🚀 部署步骤

### 方式1：使用部署脚本（推荐）
```bash
./deploy_alipay_fix.sh
```

### 方式2：手动部署
```bash
cd web
wrangler deploy
```

## 🔄 工作流程

1. **用户点击支付宝登录**
   - 前端调用 `/api/auth/alipay/login-url?platform=macos`
   - 后端返回支付宝授权URL，回调地址为 `https://flutter.ombhrum.com/api/auth/alipay/macos-callback`

2. **用户完成支付宝授权**
   - 支付宝跳转到 `https://flutter.ombhrum.com/api/auth/alipay/macos-callback?auth_code=xxx&state=xxx`

3. **后端处理回调**
   - 验证state参数
   - 使用auth_code获取支付宝用户信息
   - 检查用户是否已注册
   - 生成JWT token（如果已注册）

4. **重定向到macOS应用**
   - 已注册用户: `globaldharma://alipay_auth_code=xxx&token=xxx&username=xxx&isNewUser=false`
   - 新用户: `globaldharma://alipay_auth_code=xxx&isNewUser=true&alipay_user_id=xxx`

5. **前端处理回调**
   - 监听 `globaldharma://` scheme
   - 解析参数
   - 已注册用户直接登录
   - 新用户调用一键注册

## 🧪 测试步骤

### 1. 部署后端
```bash
./deploy_alipay_fix.sh
```

### 2. 运行macOS应用
```bash
flutter run -d macos
```

### 3. 测试支付宝登录
1. 点击"支付宝登录"按钮
2. 在浏览器中完成支付宝授权
3. 验证是否自动跳回应用
4. 检查是否成功登录

### 4. 测试支付宝一键注册
1. 使用未注册的支付宝账号
2. 点击"支付宝一键注册"按钮
3. 完成支付宝授权
4. 验证是否自动注册并登录

## 📋 验证清单

- [ ] 后端部署成功
- [ ] `/api/auth/alipay/macos-callback` 路由返回302重定向
- [ ] 重定向URL使用 `globaldharma://` scheme
- [ ] macOS应用能接收到回调
- [ ] 已注册用户能直接登录
- [ ] 新用户能一键注册
- [ ] 错误情况有正确提示

## 🔍 调试方法

### 查看后端日志
```bash
cd web
wrangler tail
```

### 测试回调URL
```bash
curl -I "https://flutter.ombhrum.com/api/auth/alipay/macos-callback?auth_code=test&state=test"
```

应该返回 302 重定向到 `globaldharma://`

### 前端调试
在 `login_screen.dart` 的 `_handleMacOSAlipayCallback` 函数中添加：
```dart
debugPrint('收到macOS支付宝回调: $url');
debugPrint('解析到的参数: $params');
```

## ⚠️ 注意事项

1. **授权码只能使用一次**
   - 后端会标记已使用的授权码
   - 重复使用会返回错误

2. **state参数有效期10分钟**
   - 超时需要重新发起授权

3. **自定义scheme配置**
   - 确保 `Info.plist` 中配置了 `globaldharma` scheme
   - 确保应用能监听URL回调

4. **网络环境**
   - 需要能访问支付宝API
   - 需要能访问 `flutter.ombhrum.com`

## 📝 相关文件

- `web/src/router.js` - 路由配置
- `web/src/handlers/thirdparty.js` - 第三方登录处理
- `web/alipay-login-functions.js` - 支付宝登录逻辑
- `lib/screens/login_screen.dart` - 前端登录界面
- `lib/services/alipay_auth_service.dart` - 支付宝认证服务
- `macos/Runner/Info.plist` - macOS配置

## 🎉 完成状态

- ✅ 后端路由已添加
- ✅ 回调处理逻辑已实现
- ✅ 前端代码已恢复
- ✅ 自定义scheme已配置
- ✅ 部署脚本已创建
- ✅ 文档已完善

## 🆘 故障排除

### 问题1：回调URL返回404
**原因**: 后端未部署或路由未生效
**解决**: 运行 `./deploy_alipay_fix.sh` 重新部署

### 问题2：应用未收到回调
**原因**: 自定义scheme未配置或未监听
**解决**: 检查 `Info.plist` 和 `_handleMacOSAlipayCallback` 函数

### 问题3：授权码无效
**原因**: 授权码已过期或已使用
**解决**: 重新点击支付宝登录按钮

### 问题4：登录失败
**原因**: 支付宝API配置错误
**解决**: 检查环境变量 `ALIPAY_APP_ID`, `ALIPAY_PRIVATE_KEY`, `ALIPAY_PUBLIC_KEY`

## 📞 技术支持

如遇问题，请查看：
- 后端日志: `wrangler tail`
- 前端日志: Flutter Debug Console
- 支付宝文档: https://opendocs.alipay.com/
