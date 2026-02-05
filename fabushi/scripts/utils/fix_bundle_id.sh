#!/bin/bash

PROJECT_ID="fabushi-71777"
CORRECT_BUNDLE_ID="com.ombhrum.fabushi"

echo "🔧 修复 Bundle ID"
echo "================="
echo "项目: $PROJECT_ID"
echo "正确的 Bundle ID: $CORRECT_BUNDLE_ID"
echo ""

echo "⚠️  当前应用使用了错误的 Bundle ID: com.example.globalDharmaSharing"
echo ""
echo "请在 Firebase Console 手动操作："
echo ""
echo "1️⃣ 删除现有应用:"
echo "   - 访问: https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
echo "   - 删除 iOS 应用 (com.example.globalDharmaSharing)"
echo "   - 删除 Web 应用"
echo ""
echo "2️⃣ 重新配置（使用正确的 Bundle ID）:"
echo "   $HOME/.pub-cache/bin/flutterfire configure \\"
echo "     --project=$PROJECT_ID \\"
echo "     --ios-bundle-id=$CORRECT_BUNDLE_ID \\"
echo "     --macos-bundle-id=$CORRECT_BUNDLE_ID \\"
echo "     --platforms=ios,macos,web \\"
echo "     --yes"
echo ""
echo "或者按 Enter 自动执行重新配置..."
read

echo "🔄 重新配置 Firebase..."
$HOME/.pub-cache/bin/flutterfire configure \
  --project=$PROJECT_ID \
  --ios-bundle-id=$CORRECT_BUNDLE_ID \
  --macos-bundle-id=$CORRECT_BUNDLE_ID \
  --platforms=ios,macos,web \
  --yes

echo ""
echo "✅ 配置完成！"
echo ""
echo "📋 查看应用列表:"
firebase apps:list --project=$PROJECT_ID
