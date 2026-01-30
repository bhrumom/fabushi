#!/bin/bash
# 强制部署新版本，破坏所有缓存

set -e

VERSION=$(date +%s)
echo "🚀 强制部署新版本: $VERSION"

# 1. 清理并构建
echo "🔨 清理并构建..."
flutter clean
flutter build web --release

# 2. 复制JS文件
echo "📋 复制JS文件..."
cp web/alipay-config.js web/auth-utils.js web/alipay-utils.js web/alipay-login-functions.js web/flutter-loading-optimizer.js build/web/

# 3. 在所有JS/CSS文件名后添加版本号
echo "🔧 添加版本号到文件名..."
cd build/web

# 重命名main.dart.js
if [ -f "main.dart.js" ]; then
    cp main.dart.js "main.dart.js?v=$VERSION"
    # 更新index.html中的引用
    sed -i.bak "s|main.dart.js|main.dart.js?v=$VERSION|g" index.html
    rm -f index.html.bak
fi

# 重命名flutter_bootstrap.js
if [ -f "flutter_bootstrap.js" ]; then
    cp flutter_bootstrap.js "flutter_bootstrap.js?v=$VERSION"
    sed -i.bak "s|flutter_bootstrap.js|flutter_bootstrap.js?v=$VERSION|g" index.html
    rm -f index.html.bak
fi

cd ../..

# 4. 部署
echo "☁️  部署到Cloudflare..."
cd web
wrangler deploy --env production

echo ""
echo "✅ 部署完成！版本: $VERSION"
echo ""
echo "🔥 现在需要清除Cloudflare缓存："
echo "   1. 访问 https://dash.cloudflare.com"
echo "   2. 选择 ombhrum.com 域名"
echo "   3. 进入 Caching > Configuration"
echo "   4. 点击 'Purge Everything'"
echo ""
echo "   或使用以下命令（需要API Token）："
echo "   curl -X POST \"https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/purge_cache\" \\"
echo "     -H \"Authorization: Bearer YOUR_API_TOKEN\" \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     --data '{\"purge_everything\":true}'"
echo ""
echo "🌐 访问: https://flutter.ombhrum.com?v=$VERSION"
echo "💡 使用无痕模式或清除浏览器缓存后访问"
