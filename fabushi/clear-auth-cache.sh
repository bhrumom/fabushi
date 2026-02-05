#!/bin/bash

echo "🧹 清理认证缓存"
echo "==============="
echo ""

echo "1️⃣ 清理 Flutter 缓存..."
flutter clean
echo "✅ Flutter 缓存已清理"
echo ""

echo "2️⃣ 清理 pub 缓存..."
flutter pub get
echo "✅ 依赖已重新获取"
echo ""

echo "3️⃣ 清理应用数据（macOS）..."
# 清理 SharedPreferences
rm -rf ~/Library/Containers/com.ombhrum.fabushi/Data/Library/Preferences/com.ombhrum.fabushi.plist 2>/dev/null || true
rm -rf ~/Library/Preferences/com.ombhrum.fabushi.plist 2>/dev/null || true

# 清理应用支持目录
rm -rf ~/Library/Containers/com.ombhrum.fabushi/Data/Library/Application\ Support/com.ombhrum.fabushi 2>/dev/null || true
rm -rf ~/Library/Application\ Support/com.ombhrum.fabushi 2>/dev/null || true

echo "✅ 应用数据已清理"
echo ""

echo "🎉 清理完成！"
echo ""
echo "📝 下一步："
echo "  1. 运行: flutter run"
echo "  2. 重新测试支付宝登录"
echo "  3. 观察日志输出"
