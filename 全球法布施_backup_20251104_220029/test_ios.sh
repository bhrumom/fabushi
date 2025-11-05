#!/bin/bash

echo "🍎 iOS平台测试脚本"
echo "=================="

# 检查iOS模拟器状态
echo "📱 检查iOS模拟器..."
flutter devices | grep ios

# 运行iOS构建测试
echo "🔨 开始构建iOS应用..."
flutter build ios --simulator --debug

if [ $? -eq 0 ]; then
    echo "✅ iOS构建成功！"
    echo "🚀 启动iOS模拟器测试..."
    flutter run -d DBB3F243-6CE8-4D2C-8918-3D081E262A12 -t lib/main_simple_test.dart
else
    echo "❌ iOS构建失败"
    echo "🔧 尝试修复步骤："
    echo "1. 清理构建缓存: flutter clean"
    echo "2. 安装iOS依赖: cd ios && pod install"
    echo "3. 重新构建"
fi