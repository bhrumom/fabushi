#!/bin/bash
# 强制清除所有缓存并重新部署

set -e

echo "🧹 强制清除所有缓存..."

# 1. 修改版本号强制更新
BUILD_VERSION=$(date +%s)
echo "📦 新版本号: $BUILD_VERSION"

# 2. 修改 flutter_service_worker.js 的版本号
echo "🔧 更新 Service Worker 版本..."
sed -i.bak "s/const serviceWorkerVersion = \"[0-9]*\"/const serviceWorkerVersion = \"$BUILD_VERSION\"/" web/index.html
rm -f web/index.html.bak

# 3. 重新构建
echo "🔨 重新构建..."
flutter build web --release --no-tree-shake-icons

# 4. 复制文件
echo "📋 复制文件..."
for file in alipay-config.js alipay-login-functions.js alipay-utils.js auth-utils.js flutter-loading-optimizer.js; do
    cp "web/$file" build/web/
    echo "  ✓ $file"
done

# 5. 注入版本号
sed -i.bak "s/__BUILD_VERSION__/$BUILD_VERSION/g" build/web/flutter-loading-optimizer.js
rm -f build/web/flutter-loading-optimizer.js.bak

# 6. 添加缓存破坏参数到index.html
echo "🔧 添加缓存破坏参数..."
sed -i.bak "s|alipay-config.js|alipay-config.js?v=$BUILD_VERSION|g" build/web/index.html
sed -i.bak "s|alipay-login-functions.js|alipay-login-functions.js?v=$BUILD_VERSION|g" build/web/index.html
sed -i.bak "s|alipay-utils.js|alipay-utils.js?v=$BUILD_VERSION|g" build/web/index.html
sed -i.bak "s|auth-utils.js|auth-utils.js?v=$BUILD_VERSION|g" build/web/index.html
rm -f build/web/index.html.bak

# 7. 部署
echo "☁️  部署..."
cd web
wrangler deploy --env production

echo ""
echo "✅ 完成！版本: $BUILD_VERSION"
echo "🌐 访问: https://flutter.ombhrum.com?v=$BUILD_VERSION"
echo ""
echo "💡 请在浏览器中："
echo "   1. 打开 https://flutter.ombhrum.com?v=$BUILD_VERSION"
echo "   2. 按 Cmd+Option+I 打开开发者工具"
echo "   3. 右键点击刷新按钮，选择'清空缓存并硬性重新加载'"
echo "   4. 或者使用无痕模式测试"
