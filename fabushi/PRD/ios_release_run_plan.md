# 运行 iOS 发布正式版本计划

## 背景
用户请求运行 iOS 的发布正式版本（Release 版本）。这通常是为了在真机上测试最终的性能，或者准备分发前的最终确认。

## 前期调研
通过查询当前连接的设备列表，发现以下可用设备：
- `00008101-00123C3C0299001E` (iOS 设备)
- `macos` (macOS 桌面)
- `chrome` (Web 浏览器)

因此，目标设备为 `00008101-00123C3C0299001E`。

## User Review Required
> [!IMPORTANT]
> 将在您的 iPhone 真机上以 Release 模式运行本应用。请确认手机已解锁并连接到该 Mac。

## Proposed Changes
此操作不涉及代码更改，仅涉及执行构建和运行命令。

## 任务清单
1. 在终端中执行命令 `flutter run -d 00008101-00123C3C0299001E --release`。
2. 监控构建输出，确保没有构建失败或签名错误。
3. 如果遇到错误，根据错误日志进行修复。
4. 应用成功运行后，记录整个流程。

## Verification Plan
### Automated Tests
- 监控 `flutter run --release` 的退出状态和日志输出，确保无严重错误崩溃。

### Manual Verification
- 用户在设备端查看 App 是否正常启动、响应流畅，并确认没有任何调试环境（Debug 标签）残留。
