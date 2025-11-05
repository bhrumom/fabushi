#!/bin/bash
# 全球法布施 - 完整部署脚本（确保所有文件都被复制）

set -e  # 遇到错误立即退出

echo "🚀 开始完整构建和部署..."

# 1. 生成版本号（使用当前时间戳）
BUILD_VERSION=$(date +%s)
echo "📦 构建版本号: $BUILD_VERSION"

# 2. 清理并构建 Flutter Web
echo "🔨 构建 Flutter Web..."
flutter clean
flutter build web --release --base-href /

# 3. 复制所有必要的Web资源文件
echo "📋 复制Web资源文件..."

# 支付宝相关文件
ALIPAY_FILES=(
    "alipay-config.js"
    "alipay-login-functions.js"
    "alipay-utils.js"
    "auth-utils.js"
)

for file in "${ALIPAY_FILES[@]}"; do
    if [ -f "web/$file" ]; then
        cp "web/$file" build/web/
        echo "  ✓ 已复制 $file"
    else
        echo "  ⚠ 警告: web/$file 未找到"
    fi
done

# Flutter加载优化器
if [ -f "web/flutter-loading-optimizer.js" ]; then
    cp web/flutter-loading-optimizer.js build/web/
    echo "  ✓ 已复制 flutter-loading-optimizer.js"
fi

# Service Worker
if [ -f "web/service-worker.js" ]; then
    cp web/service-worker.js build/web/
    echo "  ✓ 已复制 service-worker.js"
fi

# 其他配置文件
OTHER_FILES=(
    "stripe-config.js"
    "manifest.json"
    "_headers"
)

for file in "${OTHER_FILES[@]}"; do
    if [ -f "web/$file" ]; then
        cp "web/$file" build/web/
        echo "  ✓ 已复制 $file"
    fi
done

# 4. 替换版本号占位符
echo "🔧 注入版本号到 flutter-loading-optimizer.js..."
if [ -f "build/web/flutter-loading-optimizer.js" ]; then
    sed -i.bak "s/__BUILD_VERSION__/$BUILD_VERSION/g" build/web/flutter-loading-optimizer.js
    rm -f build/web/flutter-loading-optimizer.js.bak
    echo "  ✓ 版本号已注入: $BUILD_VERSION"
fi

# 5. 验证关键文件是否存在
echo "🔍 验证关键文件..."
REQUIRED_FILES=(
    "build/web/index.html"
    "build/web/main.dart.js"
    "build/web/flutter_bootstrap.js"
    "build/web/alipay-config.js"
    "build/web/alipay-login-functions.js"
    "build/web/flutter-loading-optimizer.js"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ 缺失: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo "❌ 错误: 有 $MISSING_FILES 个关键文件缺失！"
    echo "请检查构建过程。"
    exit 1
fi

# 6. 部署到 Cloudflare
echo ""
echo "☁️  部署到 Cloudflare Workers..."
cd web
wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo "📌 版本号: $BUILD_VERSION"
echo "🌐 访问: https://flutter.ombhrum.com"
echo ""
echo "💡 提示: 如果看不到更新，请："
echo "   1. 清除浏览器缓存 (Ctrl+Shift+Delete)"
echo "   2. 硬刷新页面 (Ctrl+Shift+R 或 Cmd+Shift+R)"
echo "   3. 等待1-2分钟让Cloudflare全球CDN更新"
echo ""
echo "🙏 愿此功德回向法界众生！"
