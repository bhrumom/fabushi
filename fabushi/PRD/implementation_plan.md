# 实施计划 - 解决 iOS 构建磁盘空间不足问题

目前的磁盘空间极度匮乏（仅剩 160Mi），导致 iOS 构建过程中无法创建临时目录。

## 方案内容

### 系统与全局环境清理

- **清理 Xcode 衍生数据 (DerivedData)**: 删除 `~/Library/Developer/Xcode/DerivedData` 下的所有内容。预计释放 ~5.9GB。
- **清理模拟器残留**: 运行 `xcrun simctl delete unavailable` 清理不再使用的模拟器容器。

### 项目本地清理

- **Flutter 清理**: 运行 `flutter clean`。预计释放 ~2.1GB。
- **CocoaPods 清理**: 
    - 删除 `ios/Pods` 目录。预计释放 ~1.6GB。
    - 删除 `ios/Podfile.lock`。

### 重新同步与验证

- **同步依赖**: 运行 `flutter pub get`。
- **安装 Pods**: 在 `ios` 目录下运行 `pod install`。
- **尝试构建**: 重新执行 iOS 构建命令。

## 验证方案

### 自动化验证
- 运行 `df -h` 确认可用空间已显著提升（目标 > 5GB）。
- 重新运行构建命令，观察是否仍出现目录创建失败的错误。

### 手动验证
- 用户可以尝试在 Xcode 中手动打开项目并尝试构建。
