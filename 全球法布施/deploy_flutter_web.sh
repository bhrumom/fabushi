#!/bin/bash

# Flutter Web 部署到 Cloudflare Worker 脚本
# 此脚本将构建Flutter Web应用并部署到Cloudflare Worker

set -e

echo "🚀 开始部署 Flutter Web 到 Cloudflare Worker..."

# 检查必要的工具
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装或不在 PATH 中"
    exit 1
fi

if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI 未安装或不在 PATH 中"
    echo "请运行: npm install -g wrangler"
    exit 1
fi

# 检查是否已登录 Cloudflare
if ! wrangler whoami &> /dev/null; then
    echo "❌ 未登录 Cloudflare"
    echo "请运行: wrangler login"
    exit 1
fi

# 进入项目目录
cd "$(dirname "$0")"

echo "📱 构建 Flutter Web 应用..."
flutter clean
flutter pub get
flutter build web --release --web-renderer html

# 检查构建是否成功
if [ ! -d "build/web" ]; then
    echo "❌ Flutter Web 构建失败"
    exit 1
fi

echo "✅ Flutter Web 构建完成"

# 复制后端文件到web目录（如果不存在）
if [ ! -f "web/cloudflare-backend/worker.js" ]; then
    echo "📋 复制后端文件..."
    mkdir -p web/cloudflare-backend
    cp -r ../native-web/deploy-package/* web/cloudflare-backend/
fi

# 进入web目录进行部署
cd web

echo "🔧 检查 wrangler.toml 配置..."
if [ ! -f "wrangler.toml" ]; then
    echo "❌ wrangler.toml 文件不存在"
    exit 1
fi

echo "🚀 部署到 Cloudflare Worker..."

# 部署到开发环境
echo "📤 部署到开发环境..."
wrangler deploy --env development

# 询问是否部署到生产环境
read -p "是否部署到生产环境？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 部署到生产环境..."
    wrangler deploy --env production
    echo "🎉 生产环境部署完成！"
else
    echo "⏭️  跳过生产环境部署"
fi

echo "✅ Flutter Web 部署完成！"
echo ""
echo "🌐 访问地址："
echo "  开发环境: https://fabushi-flutter-web-dev.你的账户名.workers.dev"
echo "  生产环境: https://fabushi-flutter-web-prod.你的账户名.workers.dev"
echo ""
echo "📝 后续步骤："
echo "  1. 在 Cloudflare 控制台设置环境变量（secrets）"
echo "  2. 配置自定义域名（可选）"
echo "  3. 测试 Flutter Web 应用和 API 功能"