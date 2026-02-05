#!/bin/bash

# WebSocket 功能部署脚本
# 用于快速部署启用 WebSocket 的后端

set -e

echo "🚀 开始部署 WebSocket 功能..."
echo ""

# 检查是否在项目根目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 检查 wrangler 是否安装
if ! command -v wrangler &> /dev/null; then
    echo "❌ 错误：未找到 wrangler 命令"
    echo "请先安装 wrangler: npm install -g wrangler"
    exit 1
fi

# 进入 web 目录
cd web

echo "📦 检查配置文件..."
if [ ! -f "wrangler.toml" ]; then
    echo "❌ 错误：未找到 wrangler.toml"
    exit 1
fi

if [ ! -f "worker-modular.js" ]; then
    echo "❌ 错误：未找到 worker-modular.js"
    exit 1
fi

echo "✅ 配置文件检查通过"
echo ""

# 询问部署环境
echo "请选择部署环境："
echo "1) 生产环境 (production)"
echo "2) 开发环境 (development)"
read -p "请输入选项 (1 或 2): " env_choice

case $env_choice in
    1)
        ENV="production"
        ;;
    2)
        ENV="development"
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

echo ""
echo "🌍 部署到 $ENV 环境..."
echo ""

# 部署
wrangler deploy --env $ENV

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 部署成功！"
    echo ""
    echo "📋 后续步骤："
    echo "1. 运行 Flutter 应用: flutter run"
    echo "2. 进入禅修室或全球发送页面"
    echo "3. 查看控制台日志确认 WebSocket 连接"
    echo ""
    echo "🔍 查看实时日志:"
    echo "   wrangler tail --env $ENV"
    echo ""
    echo "📖 详细文档: WEBSOCKET_ENABLED.md"
else
    echo ""
    echo "❌ 部署失败"
    echo "请检查错误信息并重试"
    exit 1
fi
