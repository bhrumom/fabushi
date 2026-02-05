#!/bin/bash

echo "🔧 修复资源加载问题..."
echo ""

# 检查资源文件
echo "📋 检查资源文件..."
if [ -f "assets/models/佛像模型.glb" ]; then
    echo "✅ 佛像模型存在"
else
    echo "❌ 佛像模型不存在"
fi

if [ -f "assets/earth_texture.jpg" ]; then
    echo "✅ 地球纹理存在"
else
    echo "❌ 地球纹理不存在"
fi

if [ -f "assets/data/concap.csv" ]; then
    echo "✅ 国家坐标数据存在"
else
    echo "❌ 国家坐标数据不存在"
fi

echo ""
echo "🧹 清理构建缓存..."
flutter clean

echo ""
echo "📦 重新获取依赖..."
flutter pub get

echo ""
echo "✅ 修复完成！"
echo ""
echo "现在运行以下命令启动应用："
echo "flutter run"
echo ""
echo "⚠️  注意：必须完全重启应用，不要使用 hot reload！"
