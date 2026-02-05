#!/bin/bash

# 会员历史记录修复部署脚本
# 用途：部署修复后的后端代码到Cloudflare Workers

set -e  # 遇到错误立即退出

echo "=========================================="
echo "会员历史记录修复 - 部署脚本"
echo "=========================================="
echo ""

# 检查是否在项目根目录
if [ ! -d "web" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 进入web目录
cd web

echo "📦 检查依赖..."
if [ ! -d "node_modules" ]; then
    echo "📥 安装依赖..."
    npm install
fi

echo ""
echo "🔍 验证修复..."
echo "检查 database.js 中的修复..."

# 检查是否包含正确的查询
if grep -q "WHERE username = ?" src/services/database.js; then
    echo "✅ getPurchaseHistory 修复已应用"
else
    echo "❌ 警告：getPurchaseHistory 可能未正确修复"
fi

if grep -q "WHERE username = ?" src/services/database.js; then
    echo "✅ getRedeemHistory 修复已应用"
else
    echo "❌ 警告：getRedeemHistory 可能未正确修复"
fi

echo ""
echo "🚀 开始部署到 Cloudflare Workers..."
echo ""

# 部署
npx wrangler deploy

echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 下一步："
echo "1. 登录管理员账号"
echo "2. 进入会员中心页面"
echo "3. 检查购买记录和兑换记录是否正常显示"
echo ""
echo "🔗 后端地址：https://flutter.ombhrum.com"
echo ""
echo "📝 测试API："
echo "  购买记录：GET /api/admin/purchase-history"
echo "  兑换记录：GET /api/admin/redeem-history"
echo ""
