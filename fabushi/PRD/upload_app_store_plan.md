# 目标：把 App 上传到 App Store

## 背景
需要将最新版本的 Flutter 应用构建并上传到 Apple 的 App Store Connect 以供审核和发布。

## 注意事项与用户确认项 (User Review Required)
> [!IMPORTANT]
> **版本号确认**：当前 `pubspec.yaml` 中的版本号是 `1.0.0+5`。App Store 要求每次上传的包拥有一个比以往更高的 Build Number。请问是否需要我代为递增此版本号（例如修改为 `1.0.0+6`）？
> **上传途径**：使用命令行工具直接上传需要您的 Apple ID 账号以及 App Specific Password（App 专用密码），或 App Store Connect API Key。如果您觉得通过对话提供这些鉴权信息存在隐私顾虑，我可以仅代您完成 `flutter build ipa --release` 的打包步骤。当生成了最终的 `.ipa` 文件后，您可以自己在 Mac 上使用 **Transporter** 软件或 **Xcode Organizer** 手动上传。
> 是否需要我全自动上传还是仅仅代为打包？

## 方案实施步骤
### 1. 更新版本与依赖
#### [MODIFY] `pubspec.yaml`
- 递增 `version` 字段的 build number（如果用户确认）。

### 2. 构建打包
- 运行 `flutter clean` & `flutter pub get` 以清理缓存并拉取依赖（确保无陈旧产物干扰）。
- 运行 `flutter build ipa --release` 进入正式的归档流程。此过程会在 `build/ios/ipa` 生成供分发的 `.ipa` 文件。

### 3. 应用上传
- 如果用户选择自动上传：执行 `xcrun altool --upload-app` 进行上传（需要用户提供相关鉴权秘钥）。
- 如果用户选择手动上传：打包结束后输出提取路径，并提示用户打开 Transporter 拖入 IPA 文件。

## 验证计划
### 手动验证
- 登陆 App Store Connect 网页版 -> 对应 App 详情页 -> TestFlight 栏目。
- 确认是否出现新版本的构建版本处于“处理中”状态。
