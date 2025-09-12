# 安卓平台开发完善指南

本文档详细说明了如何完善全球法布施应用的安卓平台开发。

## 1. 权限配置

### 1.1 必要权限
在 `AndroidManifest.xml` 中已添加以下权限：
- `INTERNET` - 网络访问权限
- `READ_EXTERNAL_STORAGE` - 读取外部存储权限
- `WRITE_EXTERNAL_STORAGE` - 写入外部存储权限
- `MANAGE_EXTERNAL_STORAGE` - 管理外部存储权限（Android 11+）

### 1.2 运行时权限请求
使用 `AndroidUtils.js` 工具类处理运行时权限请求，适配不同安卓版本。

## 2. 文件处理优化

### 2.1 URI处理
使用 `AndroidUtils.processAndroidFileUri()` 方法处理不同类型的文件URI：
- `content://` URI
- `file://` URI
- 相对路径

### 2.2 文件选择器
集成 `react-native-document-picker` 和 `react-native-image-picker` 以支持多种文件类型选择。

## 3. 构建配置

### 3.1 SDK版本
- `minSdkVersion`: 24 (Android 7.0)
- `compileSdkVersion`: 36
- `targetSdkVersion`: 36

### 3.2 架构支持
支持以下架构：
- armeabi-v7a
- arm64-v8a
- x86
- x86_64

## 4. 新架构支持

已启用React Native新架构：
- `newArchEnabled=true`
- `hermesEnabled=true`

## 5. 测试建议

### 5.1 权限测试
1. 在不同安卓版本设备上测试权限请求
2. 验证拒绝权限后的处理逻辑
3. 测试Android 11+的存储管理权限

### 5.2 文件操作测试
1. 测试不同类型文件的选择和发送
2. 验证大文件处理能力
3. 测试网络中断后的恢复机制

## 6. 性能优化建议

### 6.1 内存管理
- 合理使用React组件的生命周期方法
- 及时清理不需要的引用和监听器
- 优化图片和大文件的处理

### 6.2 网络优化
- 实现合理的超时和重试机制
- 使用连接池优化网络请求
- 实现断点续传功能

## 7. 发布准备

### 7.1 签名配置
更新 `build.gradle` 中的签名配置，使用正式的keystore文件。

### 7.2 版本管理
- 更新 `versionCode` 和 `versionName`
- 确保版本号符合发布要求

### 7.3 Proguard配置
启用Proguard以减小APK体积并保护代码。

## 8. 常见问题解决

### 8.1 权限问题
- 确保在Manifest中声明了所有必要权限
- 正确处理运行时权限请求结果

### 8.2 文件访问问题
- 使用正确的URI处理方法
- 适配Android 10+的分区存储机制

### 8.3 网络安全问题
- 配置网络安全策略
- 处理HTTPS证书验证

## 9. 后续开发建议

1. 实现后台发送服务
2. 添加发送进度通知
3. 优化UI适配不同屏幕尺寸
4. 增加离线发送队列功能
5. 实现发送历史记录功能