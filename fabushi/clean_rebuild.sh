#!/bin/bash

echo "🧹 开始清理项目..."

# 1. 清理项目
echo "📦 执行 flutter clean..."
flutter clean

# 2. 删除 Pods 缓存
echo "🗑️  删除 iOS Pods 缓存..."
rm -rf ios/Pods ios/Podfile.lock

echo "🗑️  删除 macOS Pods 缓存..."
rm -rf macos/Pods macos/Podfile.lock

# 3. 重新获取依赖
echo "📥 重新获取 Flutter 依赖..."
flutter pub get

# 4. 重新安装 iOS Pods
echo "🍎 重新安装 iOS Pods..."
cd ios && pod install && cd ..

# 5. 重新安装 macOS Pods
echo "💻 重新安装 macOS Pods..."
cd macos && pod install && cd ..

echo "✅ 清理和重建完成！"
echo "🚀 现在可以运行: flutter run"
