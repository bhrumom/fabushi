#!/bin/bash

# 清理构建缓存脚本

echo "🧹 开始清理构建缓存..."

# 清理Flutter构建缓存
flutter clean

# 清理iOS Pods
if [ -d "ios/Pods" ]; then
    echo "清理iOS Pods..."
    rm -rf ios/Pods
    rm -rf ios/.symlinks
fi

# 清理macOS Pods
if [ -d "macos/Pods" ]; then
    echo "清理macOS Pods..."
    rm -rf macos/Pods
    rm -rf macos/.symlinks
fi

# 清理构建目录
if [ -d "build" ]; then
    echo "清理build目录..."
    rm -rf build
fi

# 清理.dart_tool
if [ -d ".dart_tool" ]; then
    echo "清理.dart_tool..."
    rm -rf .dart_tool
fi

echo "✅ 清理完成！"
echo ""
echo "下一步："
echo "1. 运行: flutter pub get"
echo "2. 运行: flutter run"
