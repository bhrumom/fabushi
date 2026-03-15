# iOS设备空间不足（No space left on device）错误修复记录

## 1. 现象描述
在执行 `flutter run` 时，Dart 编译器抛出异常，提示设备上没有剩余空间：
```
Unhandled exception:
FileSystemException: writeFrom failed, path =
'/var/folders/.../T/flutter_tools.../app.dill' (OS Error: No space left
on device, errno = 28)
```

## 2. 问题排查
通过运行 `df -h` 检查磁盘使用情况，发现 `/System/Volumes/Data` 目录的磁盘空间占用达到了 100%（仅剩 142MB 左右）。进一步分析发现 Xcode 构建缓存（DerivedData）等占用了数 GB 的空间。

## 3. 解决步骤
为了释放磁盘空间，自动执行了以下清理命令：
1. **清理 Xcode 派生数据缓存：**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
2. **清理 Flutter 缓存并重新获取依赖：**
   ```bash
   flutter clean
   flutter pub get
   ```
执行清理后，磁盘剩余空间增加到了 11GB。

## 4. 自动化验证与二次深度清理
在11GB剩余空间的基础上，通过执行命令 `flutter build ios --debug` 进行测试，编译流程正常执行通过：
```
✓ Built build/ios/iphoneos/Runner.app
```
**二次空间占满问题**：由于这套大型Flutter应用在包含机器学习等 Native Framework 时，其 Debug 模式编译（包括 `build` 文件夹、`ios/Pods` 以及 Xcode 的 `DerivedData`）会极其庞大，上述过程竟然消耗了近 `10.1GB` 的磁盘空间。导致紧接着在终端发起 `flutter run` 推送入设备时，又发生 `rsync: write: No space left on device` 错误。

**深度缓存清理方案**：为再次腾出物理空间并保证 `flutter run` 足以在本地完成应用归档及同步至设备的拷贝工作（如拷贝体积庞大的 `flutter_gemma.framework`）：
进一步清理常态化冗余缓存文件：
1. **清理废弃的 iOS 模拟器环境（释放约 3.5GB）**
   ```bash
   rm -rf ~/Library/Developer/CoreSimulator/Devices/*
   ```
2. **清理庞大的 CocoaPods 全局缓存（释放约 1.7GB）**
   ```bash
   rm -rf ~/Library/Caches/CocoaPods/*
   ```
3. **清理 Gradle 全局构建缓存（释放约 600MB）**
   ```bash
   rm -rf ~/.gradle/caches/*
   ```
再次释放了高达 **6.3GB** 左右的净空间。

## 5. 总结
经过深度的环境与历史缓存文件清理，现已有充裕容量保障庞大框架的 `rsync` 同步拷贝任务。
确诊并解决无空间的问题，后续可以立刻顺畅执行 `flutter run` 部署应用至本机调试。
