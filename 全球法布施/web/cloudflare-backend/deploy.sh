#!/bin/bash

# Flutter应用Cloudflare Worker后端部署脚本
# 此脚本将部署共享的用户认证和会员系统后端

echo "🚀 开始部署Flutter应用的Cloudflare Worker后端..."

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

# 检查必要的配置文件
if [ ! -f "wrangler.toml" ]; then
    echo "❌ 错误: 未找到wrangler.toml配置文件"
    exit 1
fi

if [ ! -f "worker.js" ]; then
    echo "❌ 错误: 未找到worker.js文件"
    exit 1
fi

echo "📋 检查KV存储空间..."

# 创建KV存储空间（如果不存在）
echo "创建用户KV存储空间..."
wrangler kv:namespace create "USERS_KV" || echo "用户KV存储空间可能已存在"

echo "创建订单KV存储空间..."
wrangler kv:namespace create "ORDERS_KV" || echo "订单KV存储空间可能已存在"

echo "创建会员KV存储空间..."
wrangler kv:namespace create "MEMBERSHIP_KV" || echo "会员KV存储空间可能已存在"

echo "创建兑换码KV存储空间..."
wrangler kv:namespace create "REDEEM_CODES_KV" || echo "兑换码KV存储空间可能已存在"

echo "📦 检查R2存储桶..."
wrangler r2 bucket create bushi || echo "R2存储桶可能已存在"

echo "🔧 设置环境变量..."
echo "请确保在Cloudflare Dashboard中设置以下Secrets:"
echo "- JWT_SECRET: JWT密钥"
echo "- RESEND_API_KEY: 邮件服务API密钥（可选）"
echo "- ALIPAY_APP_ID: 支付宝应用ID（可选）"
echo "- ALIPAY_PRIVATE_KEY: 支付宝私钥（可选）"
echo "- ALIPAY_PUBLIC_KEY: 支付宝公钥（可选）"
echo "- STRIPE_SECRET_KEY: Stripe密钥（可选）"

echo "🚀 开始部署..."
wrangler deploy

if [ $? -eq 0 ]; then
    echo "✅ 部署成功！"
    echo ""
    echo "🔗 你的Worker URL: https://fabushi-prod.你的账户名.workers.dev"
    echo ""
    echo "📱 Flutter应用配置:"
    echo "请在Flutter应用中将API_BASE_URL设置为上述URL"
    echo ""
    echo "🔐 共享用户系统:"
    echo "此后端与之前部署的Web版本共享相同的用户数据库"
    echo "用户可以在Web版和移动版之间无缝切换"
    echo ""
    echo "💡 下一步:"
    echo "1. 在Cloudflare Dashboard中配置必要的Secrets"
    echo "2. 在Flutter应用中更新API端点配置"
    echo "3. 测试用户登录和会员功能"
else
    echo "❌ 部署失败，请检查错误信息"
    exit 1
fi