#!/bin/bash

# 共享素材管理验证脚本
# 用于验证首页和法流页面的素材共享功能

echo "🔍 开始验证共享素材管理功能..."
echo ""

# 检查关键文件是否存在
echo "📁 检查关键文件..."
files=(
    "lib/services/shared_asset_manager.dart"
    "lib/models/file_transfer_model.dart"
    "lib/services/cloudflare_text_service.dart"
    "SHARED_ASSET_USAGE.md"
    "SHARED_ASSET_IMPLEMENTATION.md"
)

all_files_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (缺失)"
        all_files_exist=false
    fi
done

echo ""

# 检查 SharedAssetManager 是否正确导入
echo "🔗 检查导入关系..."

if grep -q "import.*shared_asset_manager.dart" lib/models/file_transfer_model.dart; then
    echo "  ✅ FileTransferModel 已导入 SharedAssetManager"
else
    echo "  ❌ FileTransferModel 未导入 SharedAssetManager"
fi

if grep -q "import.*shared_asset_manager.dart" lib/services/cloudflare_text_service.dart; then
    echo "  ✅ CloudflareTextService 已导入 SharedAssetManager"
else
    echo "  ❌ CloudflareTextService 未导入 SharedAssetManager"
fi

echo ""

# 检查 SharedAssetManager 的使用
echo "🎯 检查 SharedAssetManager 使用..."

if grep -q "SharedAssetManager()" lib/models/file_transfer_model.dart; then
    echo "  ✅ FileTransferModel 使用了 SharedAssetManager"
else
    echo "  ❌ FileTransferModel 未使用 SharedAssetManager"
fi

if grep -q "SharedAssetManager()" lib/services/cloudflare_text_service.dart; then
    echo "  ✅ CloudflareTextService 使用了 SharedAssetManager"
else
    echo "  ❌ CloudflareTextService 未使用 SharedAssetManager"
fi

echo ""

# 检查关键方法
echo "🔧 检查关键方法..."

methods=(
    "isAssetDownloaded"
    "getDownloadedAsset"
    "downloadAsset"
    "markAssetDownloaded"
)

for method in "${methods[@]}"; do
    if grep -q "$method" lib/services/shared_asset_manager.dart; then
        echo "  ✅ $method 方法已实现"
    else
        echo "  ❌ $method 方法缺失"
    fi
done

echo ""

# 检查文档
echo "📚 检查文档完整性..."

if [ -f "SHARED_ASSET_USAGE.md" ]; then
    if grep -q "SharedAssetManager" SHARED_ASSET_USAGE.md; then
        echo "  ✅ 使用指南文档完整"
    else
        echo "  ⚠️  使用指南文档不完整"
    fi
fi

if [ -f "SHARED_ASSET_IMPLEMENTATION.md" ]; then
    if grep -q "实现完成" SHARED_ASSET_IMPLEMENTATION.md; then
        echo "  ✅ 实现报告文档完整"
    else
        echo "  ⚠️  实现报告文档不完整"
    fi
fi

if grep -q "SHARED_ASSET_USAGE.md" README.md; then
    echo "  ✅ README 已更新"
else
    echo "  ⚠️  README 未更新"
fi

echo ""

# 运行测试
echo "🧪 运行单元测试..."
if [ -f "test/shared_asset_manager_test.dart" ]; then
    echo "  ✅ 测试文件存在"
    echo "  💡 运行: flutter test test/shared_asset_manager_test.dart"
else
    echo "  ⚠️  测试文件不存在"
fi

echo ""

# 总结
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$all_files_exist" = true ]; then
    echo "✅ 验证完成！共享素材管理功能已正确实现"
    echo ""
    echo "📖 使用指南: SHARED_ASSET_USAGE.md"
    echo "📋 实现报告: SHARED_ASSET_IMPLEMENTATION.md"
    echo ""
    echo "🚀 下一步:"
    echo "  1. 运行应用测试功能"
    echo "  2. 在首页下载素材"
    echo "  3. 切换到法流页面验证复用"
    echo "  4. 反向测试（法流→首页）"
else
    echo "⚠️  部分文件缺失，请检查实现"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
