#!/bin/bash

echo "🔧 修复 iOS 构建问题..."

# 确保 Flutter 依赖和生成的配置是最新的
echo "📥 运行 flutter pub get..."
flutter pub get

# 设置 UTF-8 编码
export LANG=en_US.UTF-8

# 进入 iOS 目录
cd ios

echo "📝 更新 Podfile 配置..."
# Podfile 已经更新为 iOS 15.0

echo "🧹 清理 CocoaPods 缓存..."
rm -rf Pods Podfile.lock
pod cache clean --all 2>/dev/null || true

echo "📦 重新安装 Pods（可能需要几分钟）..."
pod install --repo-update

cd ..

echo "✅ iOS 构建修复完成！"
echo "💡 如果仍有网络问题，请检查网络连接或使用 VPN"
