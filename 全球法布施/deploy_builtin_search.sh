#!/bin/bash

# 部署内置内容全文搜索功能
# 包含数据库schema创建和代码部署

set -e

echo "🚀 开始部署内置内容全文搜索功能"
echo "=================================="

# 检查必要文件
echo "📋 检查必要文件..."
required_files=(
    "web/schema-builtin-search.sql"
    "web/migrate-builtin-handler.js"
    "migrate_builtin_to_d1.py"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ 缺少文件: $file"
        exit 1
    fi
done

echo "✅ 所有必要文件存在"

# 进入web目录
cd web

# 1. 创建数据库schema
echo ""
echo "📊 创建数据库schema..."
if command -v wrangler &> /dev/null; then
    echo "使用wrangler执行SQL..."
    wrangler d1 execute fabushi-db --file=schema-builtin-search.sql
    echo "✅ 数据库schema创建完成"
else
    echo "⚠️  wrangler未安装，请手动执行schema-builtin-search.sql"
fi

# 2. 部署Worker代码
echo ""
echo "🔧 部署Worker代码..."
if command -v wrangler &> /dev/null; then
    wrangler deploy
    echo "✅ Worker代码部署完成"
else
    echo "⚠️  wrangler未安装，请手动部署Worker"
fi

# 返回根目录
cd ..

# 3. 安装Python依赖
echo ""
echo "🐍 检查Python依赖..."
if command -v pip &> /dev/null; then
    pip install requests chardet pathlib
    echo "✅ Python依赖安装完成"
else
    echo "⚠️  pip未安装，请手动安装: requests chardet pathlib"
fi

# 4. 运行测试
echo ""
echo "🧪 运行功能测试..."
if [[ -f "test_builtin_migration.py" ]]; then
    python3 test_builtin_migration.py
else
    echo "⚠️  测试文件不存在，跳过测试"
fi

echo ""
echo "🎉 部署完成！"
echo ""
echo "📚 使用说明："
echo "1. 运行迁移脚本: python3 migrate_builtin_to_d1.py"
echo "2. 测试搜索API: curl 'https://flutter.ombhrum.com/api/builtin/search?q=般若'"
echo "3. 获取分类: curl 'https://flutter.ombhrum.com/api/builtin/categories'"
echo ""
echo "🔗 API端点："
echo "- 迁移: POST /migrate-builtin-complete"
echo "- 搜索: GET /api/builtin/search?q=关键词"
echo "- 分类: GET /api/builtin/categories"