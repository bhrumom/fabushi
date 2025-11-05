#!/bin/bash

PROJECT_ID="global-dharma-fabushi"
BUNDLE_ID="com.ombhrum.fabushi"

echo "🔥 创建新的 Firebase 项目"
echo "=========================="
echo "项目 ID: $PROJECT_ID"
echo "Bundle ID: $BUNDLE_ID"
echo ""

echo "1️⃣ 创建 Firebase 项目..."
firebase projects:create $PROJECT_ID --display-name="全球法布施"

echo ""
echo "2️⃣ 配置 FlutterFire..."
$HOME/.pub-cache/bin/flutterfire configure \
  --project=$PROJECT_ID \
  --ios-bundle-id=$BUNDLE_ID \
  --macos-bundle-id=$BUNDLE_ID \
  --android-package-name=$BUNDLE_ID \
  --platforms=ios,macos,web,android \
  --yes

echo ""
echo "3️⃣ 查看应用列表..."
firebase apps:list --project=$PROJECT_ID

echo ""
echo "✅ 完成！"
echo ""
echo "📝 下一步："
echo "1. 启用 Authentication:"
echo "   firebase open --project=$PROJECT_ID"
echo "2. 运行应用:"
echo "   flutter run -d macos"
