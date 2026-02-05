#!/bin/bash

# Firebase 配置更新脚本
# 用于更新 Android 和 iOS 的 Firebase 配置文件到新包名 com.ombhrum.fabushi

PROJECT_ID="quanqiubushi"
NEW_PACKAGE_NAME="com.ombhrum.fabushi"

echo "🔥 开始更新 Firebase 配置..."
echo "项目: $PROJECT_ID"
echo "新包名: $NEW_PACKAGE_NAME"
echo ""

# 1. 下载 Android 配置
echo "📱 下载 Android 配置..."
rm -f android/app/google-services.json
firebase apps:sdkconfig ANDROID 1:700291601159:android:6266ae078c4aa918622ba2 \
  --project $PROJECT_ID \
  -o android/app/google-services.json

if [ $? -eq 0 ]; then
  echo "✅ Android 配置下载成功"
else
  echo "❌ Android 配置下载失败"
  exit 1
fi

# 2. 下载 iOS 配置
echo ""
echo "🍎 下载 iOS 配置..."
rm -f ios/Runner/GoogleService-Info.plist
firebase apps:sdkconfig IOS 1:700291601159:ios:a37861f095a35c41622ba2 \
  --project $PROJECT_ID \
  -o ios/Runner/GoogleService-Info.plist

if [ $? -eq 0 ]; then
  echo "✅ iOS 配置下载成功"
else
  echo "❌ iOS 配置下载失败"
  exit 1
fi

# 3. 验证配置
echo ""
echo "🔍 验证配置文件..."
echo ""
echo "=== Android 包名 ==="
grep -A 1 "package_name" android/app/google-services.json | grep "com.ombhrum.fabushi" && echo "✅ Android 包名正确" || echo "⚠️  Android 包含多个应用配置"

echo ""
echo "=== iOS Bundle ID ==="
grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist | grep "com.ombhrum.fabushi" && echo "✅ iOS Bundle ID 正确" || grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist

echo ""
echo "✨ 配置更新完成！"
echo ""
echo "⚠️  注意事项："
echo "1. 如果 Android 配置包含旧包名，请在 Firebase Console 中删除旧应用"
echo "2. 如果 iOS Bundle ID 不正确，请在 Firebase Console 中更新应用配置"
echo "3. Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
