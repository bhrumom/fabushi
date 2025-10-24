#!/bin/bash

echo "🔥 Firebase 配置助手"
echo "===================="
echo ""
echo "请确保已完成以下步骤："
echo "1. ✅ 在 Firebase Console 创建项目"
echo "2. ✅ 添加 iOS/macOS 应用"
echo "3. ✅ 下载配置文件到 ~/Downloads/"
echo ""

read -p "按 Enter 继续..." 

# 复制 macOS/iOS 配置
if [ -f ~/Downloads/GoogleService-Info.plist ]; then
    cp ~/Downloads/GoogleService-Info.plist macos/Runner/
    echo "✅ macOS 配置已复制到 macos/Runner/"
else
    echo "❌ 未找到 GoogleService-Info.plist"
    echo "   请从 Firebase Console 下载到 ~/Downloads/"
fi

# 复制 Android 配置（可选）
if [ -f ~/Downloads/google-services.json ]; then
    cp ~/Downloads/google-services.json android/app/
    echo "✅ Android 配置已复制到 android/app/"
else
    echo "⚠️  未找到 google-services.json（可选）"
fi

echo ""
echo "📝 下一步操作："
echo "1. 更新 lib/firebase_options.dart 中的配置值"
echo "2. 运行: flutter clean"
echo "3. 运行: flutter pub get"
echo "4. 运行: flutter run -d macos"
echo ""
echo "📖 详细指南请查看: FIREBASE_REAL_SETUP_GUIDE.md"
