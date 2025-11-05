#!/bin/bash

echo "🌍 Flutter Earth Globe 快速测试"
echo "================================"
echo ""

# 检查依赖
echo "📦 检查依赖..."
flutter pub get

echo ""
echo "🔍 分析代码..."
flutter analyze lib/widgets/earth_globe_widget.dart
flutter analyze lib/screens/globe_home_screen.dart
flutter analyze lib/screens/earth_globe_demo_screen.dart

echo ""
echo "✅ 代码检查完成！"
echo ""
echo "🚀 运行选项："
echo "1. flutter run -d chrome    # Web 浏览器"
echo "2. flutter run -d macos     # macOS 应用"
echo "3. flutter run -d android   # Android 设备"
echo ""
echo "💡 提示："
echo "- 主界面会自动使用 GlobeHomeScreen"
echo "- 要测试演示界面，修改 main.dart 导入 EarthGlobeDemoScreen"
echo ""
echo "📚 文档："
echo "- EARTH_GLOBE_IMPLEMENTATION.md  # 实现总结"
echo "- EARTH_GLOBE_USAGE_GUIDE.md     # 完整使用指南"
echo ""
