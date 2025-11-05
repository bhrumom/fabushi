#!/bin/bash

# Web Release 构建脚本
# 用于快速构建优化的 Web 版本

echo "🚀 开始构建 Web Release 版本..."
echo ""

# 清理之前的构建
echo "🧹 清理之前的构建..."
flutter clean

# 获取依赖
echo "📦 获取依赖..."
flutter pub get

# 构建 Release 版本
echo "🔨 构建 Release 版本（优化模式）..."
flutter build web --release \
  --web-renderer canvaskit \
  --dart-define=ENVIRONMENT=production

echo ""
echo "✅ 构建完成！"
echo ""
echo "📂 构建文件位置: build/web/"
echo ""
echo "🌐 本地测试："
echo "   cd build/web"
echo "   python3 -m http.server 8000"
echo "   然后访问: http://localhost:8000"
echo ""
echo "☁️  部署到 Cloudflare Pages："
echo "   cd build/web"
echo "   wrangler pages publish . --project-name=fabushi"
echo ""
