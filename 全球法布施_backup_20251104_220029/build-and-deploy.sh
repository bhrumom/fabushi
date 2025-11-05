#!/bin/bash

# 全球法布施 - 构建和部署脚本

set -e  # 遇到错误立即退出

echo "🚀 开始构建和部署..."

# 1. 生成版本号（使用当前时间戳）
BUILD_VERSION=$(date +%s)
echo "📦 构建版本号: $BUILD_VERSION"

# 2. 清理并构建 Flutter Web
echo "🔨 构建 Flutter Web..."
flutter clean
flutter build web --release

# 2.5 复制必要的Web资源文件
echo "📋 复制Web资源文件..."
for file in alipay-config.js alipay-login-functions.js alipay-utils.js auth-utils.js flutter-loading-optimizer.js; do
    if [ -f "web/$file" ]; then
        cp "web/$file" build/web/
        echo "  ✓ 已复制 $file"
    else
        echo "  ⚠ 警告: web/$file 未找到"
    fi
done

# 3. 替换版本号占位符
echo "🔧 注入版本号到 flutter-loading-optimizer.js..."
sed -i.bak "s/__BUILD_VERSION__/$BUILD_VERSION/g" build/web/flutter-loading-optimizer.js
rm -f build/web/flutter-loading-optimizer.js.bak

# 4. 部署到 Cloudflare
echo "☁️  部署到 Cloudflare Workers..."
cd web
wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo "📌 版本号: $BUILD_VERSION"
echo "🌐 访问: https://flutter.ombhrum.com"
echo ""
echo "🙏 愿此功德回向法界众生！"
