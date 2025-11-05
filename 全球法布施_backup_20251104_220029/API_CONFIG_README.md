# API配置统一管理系统

## 概述

为了解决所有平台统一使用配置部署后地址总是出现登录出错的问题，我们创建了一个统一的API配置管理系统。这个系统可以：

- 统一管理所有平台的API配置
- 智能选择最佳的后端地址
- 提供自动故障转移功能
- 支持用户自定义后端地址
- 提供友好的设置界面

## 主要文件

### 1. 统一配置文件
- `lib/config/unified_config.dart` - 核心配置管理
- `lib/services/unified_api_service.dart` - 统一API服务
- `lib/services/app_initializer.dart` - 应用初始化服务

### 2. 用户界面
- `lib/screens/api_settings_screen.dart` - API设置界面
- `lib/widgets/app_wrapper.dart` - 应用包装器

### 3. 更新的文件
- `lib/main.dart` - 添加了应用初始化
- `lib/services/app_settings.dart` - 更新为使用统一配置
- `lib/screens/settings_screen.dart` - 添加了API设置入口
- `lib/config.dart` - 标记为已弃用，保持向后兼容

## 配置优先级

系统按以下优先级选择后端地址：

1. **用户自定义地址** - 如果用户在设置中指定了自定义地址
2. **主要后端地址** - `https://ombhrum.com` (推荐)
3. **Cloudflare Worker** - 作为备用地址
4. **本地开发地址** - 仅在开发环境中使用

## 环境变量控制

可以通过以下环境变量控制配置：

```bash
# 指定环境
--dart-define=ENVIRONMENT=production  # 或 development

# 强制使用Cloudflare Worker
--dart-define=USE_CLOUDFLARE=true

# 使用本地开发服务器
--dart-define=USE_LOCAL=true

# 启用调试模式
--dart-define=DEBUG=true
```

## 使用方法

### 1. 用户设置

用户可以通过以下步骤配置API：

1. 打开应用
2. 进入"设置"页面
3. 点击"API设置"
4. 选择预设的后端地址或输入自定义地址
5. 点击"测试连接"验证
6. 保存设置

### 2. 开发者配置

开发者可以通过代码配置：

```dart
// 获取当前后端URL
String currentUrl = UnifiedConfig.currentBackendUrl;

// 使用统一API服务
final apiService = UnifiedApiService();
await apiService.login(email, password);

// 检查后端健康状态
bool isHealthy = await apiService.checkHealth();

// 寻找可用的后端
String? workingUrl = await apiService.findWorkingBackend();
```

## 自动故障转移

系统提供自动故障转移功能：

1. **健康检查** - 应用启动时自动检查后端连接
2. **自动切换** - 如果当前后端不可用，自动寻找可用的备用地址
3. **重试机制** - 请求失败时自动重试，最多3次
4. **用户通知** - 在设置界面显示连接状态

## 预设后端地址

系统预设了以下后端地址：

1. **主要后端** - `https://ombhrum.com`
   - 推荐使用
   - 稳定可靠

2. **Cloudflare Worker (生产)** - `https://flutter.ombhrum.com`
   - 全球CDN加速
   - 适合海外用户

3. **Cloudflare Worker (开发)** - `https://flutter.ombhrum.com`
   - 开发测试环境
   - 用于测试新功能

## 故障排除

### 登录失败问题

如果遇到登录失败，请按以下步骤排查：

1. **检查网络连接**
   - 确保设备可以访问互联网

2. **测试后端连接**
   - 进入"设置" → "API设置"
   - 点击"测试连接"按钮

3. **尝试不同的后端**
   - 在API设置中选择不同的预设地址
   - 或使用"自动寻找"功能

4. **检查错误日志**
   - 查看控制台输出的详细错误信息

### 常见错误

1. **ClientException: Failed to fetch**
   - 原因：后端地址不可访问
   - 解决：切换到其他可用的后端地址

2. **请求超时**
   - 原因：网络连接慢或后端响应慢
   - 解决：检查网络连接，或切换到更快的后端

3. **认证失败**
   - 原因：用户凭据无效或后端配置问题
   - 解决：检查用户名密码，或联系管理员

## 开发指南

### 添加新的后端地址

1. 在 `UnifiedConfig.fallbackUrls` 中添加新地址
2. 在 `ApiSettingsScreen` 的 `_backendOptions` 中添加选项
3. 测试新地址的可用性

### 添加新的API端点

1. 在 `UnifiedConfig` 中添加新的URL getter
2. 在 `UnifiedApiService` 中添加对应的方法
3. 更新相关的服务文件

### 自定义初始化逻辑

在 `AppInitializer` 中添加自定义的初始化步骤：

```dart
static Future<void> _customInitialization() async {
  // 添加自定义初始化逻辑
}
```

## 部署说明

### Web部署

确保 `web/wrangler.toml` 配置正确：

```toml
[env.production]
name = "fabushi-flutter-web-prod"

[env.development]
name = "fabushi-flutter-web-dev"
```

### 移动端部署

构建时指定环境：

```bash
# 生产环境
flutter build apk --dart-define=ENVIRONMENT=production

# 开发环境
flutter build apk --dart-define=ENVIRONMENT=development
```

## 监控和日志

系统提供详细的日志记录：

- API请求和响应日志
- 连接状态变化
- 错误详情和重试信息
- 配置变更记录

可以通过 `UnifiedConfig.enableApiLogging` 控制日志输出。

## 更新历史

- **v1.0** - 创建统一配置系统
- **v1.1** - 添加自动故障转移
- **v1.2** - 添加用户友好的设置界面
- **v1.3** - 添加健康检查和监控功能

## 支持

如果遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查控制台日志输出
3. 在设置界面测试不同的后端地址
4. 联系开发团队获取支持