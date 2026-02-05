#!/bin/bash

PROJECT_ID="quanqiubushi"

echo "🔄 更新 Google 登录配置文件"
echo "=============================="
echo ""
echo "项目: $PROJECT_ID"
echo ""

echo "1️⃣ 重新配置 FlutterFire（下载最新配置）..."
$HOME/.pub-cache/bin/flutterfire configure \
  --project=$PROJECT_ID \
  --platforms=ios,macos,web,android \
  --yes

echo ""
echo "2️⃣ 验证配置文件..."
echo ""

if [ -f "android/app/google-services.json" ]; then
    echo "✅ Android: google-services.json 已更新"
    echo "   位置: android/app/google-services.json"
else
    echo "❌ Android: google-services.json 未找到"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ iOS: GoogleService-Info.plist 已更新"
    echo "   位置: ios/Runner/GoogleService-Info.plist"
else
    echo "❌ iOS: GoogleService-Info.plist 未找到"
fi

if [ -f "macos/Runner/GoogleService-Info.plist" ]; then
    echo "✅ macOS: GoogleService-Info.plist 已更新"
    echo "   位置: macos/Runner/GoogleService-Info.plist"
else
    echo "❌ macOS: GoogleService-Info.plist 未找到"
fi

echo ""
echo "3️⃣ 清理并重新构建..."
flutter clean
flutter pub get

echo ""
echo "✅ 配置更新完成！"
echo ""
echo "📝 下一步："
echo "1. 运行应用: flutter run -d macos"
echo "2. 测试 Google 登录功能"
