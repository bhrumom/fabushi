#!/bin/bash

echo "🔧 开始修复全球法布施应用..."

# 进入项目目录
cd "$(dirname "$0")"

echo "📦 清理项目..."
flutter clean

echo "📥 获取依赖..."
flutter pub get

echo "🍎 重新安装CocoaPods..."
cd macos
pod install
cd ..

echo "🚀 启动应用..."
flutter run -d macos

echo "✅ 修复完成！"