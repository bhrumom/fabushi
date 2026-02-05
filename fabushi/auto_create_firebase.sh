#!/bin/bash

BUNDLE_ID="com.ombhrum.fabushi"
PROJECT_NAME="fabushi-app-$(date +%s)"

echo "🔥 Firebase 项目一键创建"
echo "========================"
echo ""
echo "项目名称: 全球法布施"
echo "项目 ID: $PROJECT_NAME"
echo "Bundle ID: $BUNDLE_ID"
echo ""

echo "1️⃣ 创建 Firebase 项目..."
firebase projects:create "$PROJECT_NAME" \
  --display-name="全球法布施" 2>&1 | tee /tmp/firebase_create.log

if grep -q "Error" /tmp/firebase_create.log; then
    echo "❌ 项目创建失败，可能已存在"
    echo ""
    echo "请手动创建项目："
    echo "1. 访问: https://console.firebase.google.com"
    echo "2. 点击 '添加项目'"
    echo "3. 创建后运行:"
    echo "   bash create_firebase_project_complete.sh"
    exit 1
fi

echo ""
echo "⏳ 等待项目初始化（30秒）..."
sleep 30

echo ""
echo "2️⃣ 配置 FlutterFire..."
$HOME/.pub-cache/bin/flutterfire configure \
  --project="$PROJECT_NAME" \
  --ios-bundle-id="$BUNDLE_ID" \
  --macos-bundle-id="$BUNDLE_ID" \
  --android-package-name="$BUNDLE_ID" \
  --platforms=ios,macos,web,android \
  --yes

echo ""
echo "3️⃣ 查看应用列表..."
firebase apps:list --project="$PROJECT_NAME"

echo ""
echo "4️⃣ 保存项目信息..."
echo "$PROJECT_NAME" > .firebase_project_id
echo "Bundle ID: $BUNDLE_ID" >> .firebase_project_id

echo ""
echo "✅ 完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 下一步："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 启用 Authentication:"
echo "   firebase open --project=$PROJECT_NAME"
echo ""
echo "2. 在 Firebase Console:"
echo "   - 点击 Authentication > 开始使用"
echo "   - 启用 Email/Password"
echo "   - 启用 Google"
echo ""
echo "3. 运行应用:"
echo "   flutter run -d macos"
echo ""
echo "项目 ID: $PROJECT_NAME"
