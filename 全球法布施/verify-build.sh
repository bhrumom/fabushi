#!/bin/bash
# 验证构建输出是否包含所有必要的文件

echo "🔍 验证构建输出..."
echo ""

# 检查构建目录是否存在
if [ ! -d "build/web" ]; then
    echo "❌ build/web 目录不存在！"
    echo "请先运行: flutter build web --release"
    exit 1
fi

# 必需的文件列表
REQUIRED_FILES=(
    "build/web/index.html"
    "build/web/main.dart.js"
    "build/web/flutter_bootstrap.js"
    "build/web/flutter-loading-optimizer.js"
    "build/web/alipay-config.js"
    "build/web/alipay-login-functions.js"
    "build/web/alipay-utils.js"
    "build/web/auth-utils.js"
)

MISSING_COUNT=0
FOUND_COUNT=0

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
        FOUND_COUNT=$((FOUND_COUNT + 1))
    else
        echo "✗ 缺失: $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

echo ""
echo "统计: $FOUND_COUNT 个文件存在, $MISSING_COUNT 个文件缺失"

# 检查index.html中的引用
echo ""
echo "🔍 检查 index.html 中的脚本引用..."
if [ -f "build/web/index.html" ]; then
    if grep -q "alipay-config.js" build/web/index.html; then
        echo "✓ alipay-config.js 已引用"
    else
        echo "✗ alipay-config.js 未引用"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
    
    if grep -q "alipay-login-functions.js" build/web/index.html; then
        echo "✓ alipay-login-functions.js 已引用"
    else
        echo "✗ alipay-login-functions.js 未引用"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
fi

echo ""
if [ $MISSING_COUNT -eq 0 ]; then
    echo "✅ 所有检查通过！构建输出完整。"
    echo "可以安全部署到 Cloudflare。"
    exit 0
else
    echo "❌ 发现 $MISSING_COUNT 个问题！"
    echo "请运行 ./deploy-complete.sh 重新构建。"
    exit 1
fi
