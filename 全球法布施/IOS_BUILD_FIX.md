# iOS 构建问题修复指南

## 已修复的问题

### 1. ✅ Tobias 插件配置
已在 `pubspec.yaml` 中添加必需的 `url_scheme` 配置：
```yaml
tobias:
  url_scheme: fabushi
```

### 2. ✅ iOS 平台版本
已将 `ios/Podfile` 中的最低版本提升到 iOS 15.0：
```ruby
platform :ios, '15.0'
```

## 当前问题

### 网络连接问题
CocoaPods 在下载 SDWebImage 时遇到 GitHub 连接超时。

## 解决方案

### 方案 1：重试安装（推荐）
```bash
cd ios
export LANG=en_US.UTF-8
pod install --repo-update
```

### 方案 2：使用修复脚本
```bash
./fix_ios_build.sh
```

### 方案 3：配置 Git 代理（如果有 VPN）
```bash
# 设置 Git 代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 然后重新安装
cd ios && pod install
```

### 方案 4：跳过 iOS，先运行其他平台
```bash
# 运行 Android
flutter run -d android

# 运行 macOS（如果不需要支付宝）
flutter run -d macos

# 运行 Web
flutter run -d chrome
```

## 临时解决方案：移除 Tobias

如果不需要支付宝支付功能，可以暂时移除 tobias 依赖：

1. 编辑 `pubspec.yaml`，注释掉：
```yaml
# tobias: ^5.3.0  # 支付宝
```

2. 重新获取依赖：
```bash
flutter pub get
cd ios && pod install
```

## 验证修复

安装成功后，运行：
```bash
flutter run -d ios
```

或者在 Xcode 中打开项目：
```bash
open ios/Runner.xcworkspace
```
