#!/bin/bash

# Flutter Web部署到Cloudflare脚本
# 此脚本将构建Flutter Web应用并部署到Cloudflare Pages

echo "🚀 开始部署Flutter Web应用到Cloudflare..."

# 检查Flutter是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到Flutter SDK"
    echo "请先安装Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# 检查是否安装了wrangler
if ! command -v wrangler &> /dev/null; then
    echo "❌ 错误: 未找到wrangler CLI工具"
    echo "请先安装: npm install -g wrangler"
    exit 1
fi

# 检查是否已登录Cloudflare
if ! wrangler whoami &> /dev/null; then
    echo "🔐 请先登录Cloudflare账户..."
    wrangler login
fi

echo "📦 清理之前的构建文件..."
flutter clean

echo "📥 获取依赖..."
flutter pub get

echo "🔧 启用Flutter Web支持..."
flutter config --enable-web

echo "🏗️ 构建Flutter Web应用..."
flutter build web --release --web-renderer html

# 检查构建是否成功
if [ ! -d "build/web" ]; then
    echo "❌ Flutter Web构建失败"
    exit 1
fi

echo "✅ Flutter Web构建成功"

# 复制配置文件到构建目录
echo "📋 复制Cloudflare配置文件..."
cp web/_headers build/web/ 2>/dev/null || echo "警告: _headers文件不存在"
cp web/_redirects build/web/ 2>/dev/null || echo "警告: _redirects文件不存在"

# 检查wrangler.toml配置
if [ ! -f "web/wrangler.toml" ]; then
    echo "❌ 错误: 未找到web/wrangler.toml配置文件"
    echo "请先创建wrangler.toml配置文件"
    exit 1
fi

echo "🚀 部署到Cloudflare Pages..."

# 进入web目录进行部署
cd web

# 使用wrangler部署
wrangler pages deploy ../build/web --project-name fabushi-flutter-web

if [ $? -eq 0 ]; then
    echo "✅ 部署成功！"
    echo ""
    echo "🔗 你的Flutter Web应用URL:"
    echo "https://fabushi-flutter-web.pages.dev"
    echo ""
    echo "📱 应用功能:"
    echo "- 用户注册和登录"
    echo "- 邮箱验证"
    echo "- 会员系统"
    echo "- 支付功能"
    echo "- 与移动版数据同步"
    echo ""
    echo "🔧 自定义域名配置:"
    echo "1. 在Cloudflare Dashboard中配置自定义域名"
    echo "2. 更新DNS记录指向Cloudflare Pages"
    echo "3. 在wrangler.toml中配置自定义域名"
    echo ""
    echo "💡 下一步:"
    echo "1. 测试Web应用的所有功能"
    echo "2. 配置自定义域名（可选）"
    echo "3. 设置CI/CD自动部署（可选）"
else
    echo "❌ 部署失败，请检查错误信息"
    exit 1
fi