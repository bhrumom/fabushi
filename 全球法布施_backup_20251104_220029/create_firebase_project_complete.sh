#!/bin/bash

BUNDLE_ID="com.ombhrum.fabushi"

echo "🔥 Firebase 项目完整创建脚本"
echo "=============================="
echo ""
echo "Bundle ID: $BUNDLE_ID"
echo ""
echo "请按照以下步骤操作："
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 1: 在 Firebase Console 创建新项目"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 访问: https://console.firebase.google.com"
echo "2. 点击 '添加项目'"
echo "3. 项目名称: 全球法布施"
echo "4. 项目 ID: 记下这个 ID（例如：fabushi-xxxxx）"
echo "5. Google Analytics: 关闭（可选）"
echo "6. 点击 '创建项目'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 2: 输入项目 ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "请输入 Firebase 项目 ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ 项目 ID 不能为空"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 3: 配置 FlutterFire"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "正在配置项目: $PROJECT_ID"
echo "Bundle ID: $BUNDLE_ID"
echo ""

$HOME/.pub-cache/bin/flutterfire configure \
  --project=$PROJECT_ID \
  --ios-bundle-id=$BUNDLE_ID \
  --macos-bundle-id=$BUNDLE_ID \
  --android-package-name=$BUNDLE_ID \
  --platforms=ios,macos,web,android \
  --yes

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 4: 查看已注册的应用"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
firebase apps:list --project=$PROJECT_ID

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 5: 启用 Authentication"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 打开 Firebase Console:"
echo "   firebase open --project=$PROJECT_ID"
echo ""
echo "2. 点击 'Authentication' > '开始使用'"
echo "3. 启用 'Email/Password'"
echo "4. 启用 'Google'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "步骤 6: 测试应用"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "flutter run -d macos"
echo ""
echo "✅ 配置完成！"
echo ""
echo "保存项目 ID 到文件..."
echo "$PROJECT_ID" > .firebase_project_id

echo ""
echo "📝 项目 ID 已保存到: .firebase_project_id"
echo "   下次可以直接使用: cat .firebase_project_id"
