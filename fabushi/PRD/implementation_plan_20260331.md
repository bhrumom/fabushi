# 修改版本号与应用名称并打包

用户要求将版本号改为 13，包名（应用名称）改为“大乘”，并重新打包。

## 用户审核

> [!IMPORTANT]
> 1. **版本号**: 目前 `pubspec.yaml` 中的版本号已经是 `1.0.0+13`。我将保持构建号（Build Number）为 13。如果您指的是版本名称（Version Name）也改为 13（例如 `13.0.0`），请告知。目前暂定保持 `1.0.0+13`。
> 2. **包名/应用名**: Android 和 iOS 的原生配置（`AndroidManifest.xml` 和 `Info.plist`）已经设置为“大乘”。但 Dart 代码层面的配置（`app_config.dart` 和 `app_constants.dart`）仍显示为“全球法布施”。我将统一修改这些部分。
> 3. **打包平台**: 默认将打包 Android APK。如果需要 iOS 或其他平台，请告知。

## 拟议变更

### 配置文件修改

#### [MODIFY] [app_config.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/core/config/app_config.dart)
- 将 `appName` 从 '全球法布施' 修改为 '大乘'。

#### [MODIFY] [app_constants.dart](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/core/constants/app_constants.dart)
- 将 `appName` 从 '全球法布施' 修改为 '大乘'。

#### [MODIFY] [pubspec.yaml](file:///Users/gloriachan/Documents/fabushi/fabushi/pubspec.yaml)
- 确认版本号为 `1.0.0+13`。

### 自动任务

1. 运行 `flutter pub get`。
2. 运行 `flutter build apk --release` 进行打包。

## 验证方案

### 自动化测试
- 检查打包是否成功。
- 使用 `grep` 验证代码中不再包含旧名称的硬编码字符串（在关键配置处）。

### 手册验证
- 检查生成的 APK 文件名或安装后的应用名称。
