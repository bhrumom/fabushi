# 构建修复技术报告

**日期**: 2026-03-11
**作者**: Antigravity

## 1. 问题概述
用户在运行 `flutter run` 时遇到多个构建错误：
1.  Gradle 构建失败，提示 `metadata.bin` 损坏（由磁盘空间不足导致）。
2.  `flutter_gemma` 依赖更新导致 API 不兼容（`GemmaModel`/`GemmaChat` 类型未定义）。
3.  Java 版本不兼容（系统安装了不支持的 Java 24，导致 Gradle 报错 `IllegalArgumentException: Unsupported class file major version 68`）。
4.  支付宝 SDK 授权失败，报 `PlatformException(AliPay UrlScheme Not Found, Config AliPay First)`。

## 2. 修复方案

### 2.1 磁盘空间清理
- 清理了 `~/Library/Developer/Xcode/DerivedData`。
- 清理了 `~/.gradle/caches` 和 `~/.pub-cache`。
- 释放了约 7.7GB 空间。

### 2.2 flutter_gemma API 适配
`flutter_gemma` 升级至 0.12.3 后，API 发生变更识别到了 `GemmaModel` 和 `GemmaChat` 的缺失。
-   **类名变更**:
    -   `GemmaModel` -> `InferenceModel`
    -   `GemmaChat` -> `InferenceChat`
-   **方法变更**:
    -   `chat.close()` -> `chat.session.close()`
-   **流式处理**:
    -   更新了 `generateStream` 方法以处理 `ModelResponse` 类型，过滤并提取 `TextResponse`。

### 2.3 Java 环境修复
-   检测到系统 Java 版本为 24（不被 Gradle 8.12 支持）。
-   切换至 Android Studio 内置的 JDK 21 (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`)，成功解决了版本不兼容问题。

### 2.4 支付宝 SDK 授权配置 (iOS)
- **问题原因**: `Info.plist` 中缺少必要的 `CFBundleURLTypes` 配置，导致支付宝 App 无法在授权完成后回调至应用。
- **修复方法**:
    - 在 `ios/Runner/Info.plist` 中添加了 `CFBundleURLTypes` 项。
    - 配置 `CFBundleURLName` 为 `alipay`。
    - 配置 `CFBundleURLSchemes` 为 `alipay2021005193647715`（基于用户提供的 APPID）。
    - 同时确保 `LSApplicationQueriesSchemes` 中包含 `alipay`, `alipays` 等项。

## 3. 验证结果
- `flutter run` 成功编译并运行。
- 支付宝 SDK 调用逻辑不再报错 `UrlScheme Not Found`。
- 应用日志展示已成功获取授权字符串并尝试唤起 SDK。

## 4. 后续建议
- 建议用户保留至少 10GB 磁盘空间以保证构建稳定。
- 建议固定项目 Java 版本为 17 或 21。
