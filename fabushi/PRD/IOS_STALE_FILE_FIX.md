# 修复 iOS 构建错误: Stale file outside of allowed root paths

## 问题描述
在执行 iOS 构建或运行时，遇到了 Xcode 依赖相关的构建错误：
`Stale file '/Users/gloriachan/Documents/fabushi/fabushi/build/ios/Debug-iphoneos/tobias/tobias.framework/Headers/TobiasPlugin.h' is located outside of the allowed root paths.`

## 发生原因
这个错误通常发生在 Xcode 15 启用了 User Script Sandboxing（用户脚本沙盒）的情况下，或者是由于项目中缓存了旧的构建文件（例如在 `build/ios` 中遗留下的 CocoaPods 插件符号链接），未随项目改动被自动清理而形成“陈旧(Stale)文件”。

## 执行计划与解决记录
1. **清理缓存：** 
   - 运行了 `flutter clean` 清除应用级别的旧构建产物。
   - 删除了 `ios/Pods` 目录解决 CocoaPods 遗留模块问题。
   - 删除了 Xcode `~/Library/Developer/Xcode/DerivedData/*` 取消引用那些跨项目的全局预编译文件。
2. **重置依赖：** 
   - 运行 `flutter pub get` 重新生成 `Generated.xcconfig`，并在 `ios/` 目录运行 `pod install` 以最新配置生成全新的构建规则。
3. **自动化测试验证（已完成）：** 
   - 依赖安装完成后，运行 `flutter build ios --debug --no-codesign` 确认构建通过。
   - 结果：`✓ Built build/ios/iphoneos/Runner.app`，成功去除了陈旧文件的缓存报错。

## 结论
通过完整的构建与 Xcode 的深度缓存清理，遗留文件缓存报错已被完全修复，当前已不再拦截 Flutter 预编译路径。
