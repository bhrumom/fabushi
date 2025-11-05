#!/bin/bash

# 全球法布施 - 清除缓存并重新部署脚本

echo "🚀 开始清除缓存并重新部署..."

# 1. 清理 Flutter 构建缓存
echo "📦 清理 Flutter 构建缓存..."
flutter clean

# 2. 重新构建 Flutter Web（添加版本号到构建中）
echo "🔨 重新构建 Flutter Web..."
flutter build web --release --web-renderer html

# 3. 添加缓存破坏参数到 index.html
echo "🔧 添加版本号到 index.html..."
TIMESTAMP=$(date +%s)
sed -i.bak "s/main.dart.js/main.dart.js?v=$TIMESTAMP/g" build/web/index.html
rm -f build/web/index.html.bak

# 4. 部署到 Cloudflare
echo "☁️  部署到 Cloudflare Workers..."
cd web
wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo ""
echo "📝 接下来请手动执行以下步骤："
echo ""
echo "1. 清除 Cloudflare 缓存："
echo "   - 访问 https://dash.cloudflare.com"
echo "   - 选择域名 ombhrum.com"
echo "   - 进入 Caching -> Configuration"
echo "   - 点击 'Purge Everything'"
echo ""
echo "2. 清除浏览器缓存："
echo "   - 打开 https://flutter.ombhrum.com"
echo "   - 按 F12 打开开发者工具"
echo "   - 进入 Application 标签"
echo "   - 左侧选择 Service Workers"
echo "   - 点击 Unregister 注销 Service Worker"
echo "   - 按 Cmd+Shift+R 强制刷新页面"
echo ""
echo "🙏 愿此功德回向法界众生！"
