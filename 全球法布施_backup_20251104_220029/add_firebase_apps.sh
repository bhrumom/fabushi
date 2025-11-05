#!/bin/bash

PROJECT_ID="fabushi-71777"
BUNDLE_ID="com.ombhrum.fabushi"
APP_NAME="全球法布施"

echo "🔥 Firebase 应用一键添加脚本"
echo "================================"
echo "项目: $PROJECT_ID"
echo "Bundle ID: $BUNDLE_ID"
echo ""

# 添加 iOS 应用
echo "📱 添加 iOS 应用..."
firebase apps:create IOS --project="$PROJECT_ID" <<EOF
$BUNDLE_ID
EOF

# 添加 Android 应用
echo "🤖 添加 Android 应用..."
firebase apps:create ANDROID --project="$PROJECT_ID" <<EOF
$BUNDLE_ID
EOF

# 添加 Web 应用
echo "🌐 添加 Web 应用..."
firebase apps:create WEB --project="$PROJECT_ID" <<EOF
$APP_NAME
EOF

echo ""
echo "✅ 应用添加完成！"
echo ""
echo "📋 查看应用列表:"
firebase apps:list --project="$PROJECT_ID"

echo ""
echo "🔧 下一步: 重新运行 FlutterFire 配置"
echo "   flutterfire configure --project=$PROJECT_ID"
