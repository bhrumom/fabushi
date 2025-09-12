#!/bin/bash

# Stripe支付系统快速配置脚本
# 使用方法: ./setup-stripe.sh

echo "🚀 Stripe支付系统配置助手"
echo "================================"

# 检查是否安装了wrangler
if ! command -v wrangler &> /dev/null; then
    echo "❌ 未找到wrangler CLI工具"
    echo "请先安装: npm install -g wrangler"
    exit 1
fi

echo "✅ 检测到wrangler CLI"

# 获取Stripe密钥
echo ""
echo "📝 请输入Stripe配置信息:"
echo "（可以从 https://dashboard.stripe.com/apikeys 获取）"
echo ""

read -p "🔑 Stripe Secret Key (sk_test_... 或 sk_live_...): " STRIPE_SECRET_KEY
read -p "🔐 Stripe Webhook Secret (whsec_...): " STRIPE_WEBHOOK_SECRET
read -p "📧 发件人邮箱 (可选，直接回车跳过): " FROM_EMAIL

# 验证必需字段
if [[ -z "$STRIPE_SECRET_KEY" ]]; then
    echo "❌ Stripe Secret Key 不能为空"
    exit 1
fi

if [[ -z "$STRIPE_WEBHOOK_SECRET" ]]; then
    echo "❌ Stripe Webhook Secret 不能为空"
    exit 1
fi

# 设置环境变量
echo ""
echo "⚙️  正在设置环境变量..."

wrangler secret put STRIPE_SECRET_KEY <<< "$STRIPE_SECRET_KEY"
if [ $? -eq 0 ]; then
    echo "✅ STRIPE_SECRET_KEY 设置成功"
else
    echo "❌ STRIPE_SECRET_KEY 设置失败"
    exit 1
fi

wrangler secret put STRIPE_WEBHOOK_SECRET <<< "$STRIPE_WEBHOOK_SECRET"
if [ $? -eq 0 ]; then
    echo "✅ STRIPE_WEBHOOK_SECRET 设置成功"
else
    echo "❌ STRIPE_WEBHOOK_SECRET 设置失败"
    exit 1
fi

if [[ -n "$FROM_EMAIL" ]]; then
    wrangler secret put FROM_EMAIL <<< "$FROM_EMAIL"
    if [ $? -eq 0 ]; then
        echo "✅ FROM_EMAIL 设置成功"
    else
        echo "⚠️  FROM_EMAIL 设置失败，但不影响核心功能"
    fi
fi

echo ""
echo "🎉 环境变量配置完成！"
echo ""
echo "📋 下一步操作:"
echo "1. 在Stripe Dashboard中创建产品和价格"
echo "2. 更新 stripe-config.js 中的价格ID"
echo "3. 更新 membership.html 中的可发布密钥"
echo "4. 配置Webhook端点: https://your-domain.workers.dev/api/stripe/webhook"
echo ""
echo "📖 详细配置说明请查看: STRIPE_SETUP.md"
echo ""
echo "🧪 测试配置: 访问 https://your-domain.workers.dev/test-stripe.html"