#!/bin/bash

# JWT 配置检查脚本

echo "🔍 JWT 配置检查"
echo "================"
echo ""

# 检查 wrangler.toml
echo "📄 检查 wrangler.toml 配置..."
echo ""

if [ ! -f "web/wrangler.toml" ]; then
    echo "❌ 找不到 web/wrangler.toml"
    exit 1
fi

echo "生产环境配置："
echo "---"
grep -A 10 "\[env.production.vars\]" web/wrangler.toml | grep -E "(JWT_SECRET|FROM_EMAIL|FLUTTER_WEB)"
echo ""

echo "开发环境配置："
echo "---"
grep -A 10 "\[env.development.vars\]" web/wrangler.toml | grep -E "(JWT_SECRET|FROM_EMAIL|FLUTTER_WEB)"
echo ""

# 检查 Cloudflare Secrets
echo "🔐 检查 Cloudflare Secrets..."
echo ""

cd web

if wrangler whoami &> /dev/null; then
    echo "生产环境 Secrets："
    wrangler secret list --env production 2>/dev/null || echo "  ❌ 无法获取 secrets 列表"
    echo ""
    
    echo "开发环境 Secrets："
    wrangler secret list --env development 2>/dev/null || echo "  ❌ 无法获取 secrets 列表"
    echo ""
else
    echo "❌ 未登录 Cloudflare，无法检查 secrets"
    echo "   请运行: wrangler login"
    echo ""
fi

cd ..

# 分析结果
echo "📊 分析结果："
echo "---"

has_prod_jwt_in_toml=$(grep -A 10 "\[env.production.vars\]" web/wrangler.toml | grep "JWT_SECRET" | wc -l)
has_dev_jwt_in_toml=$(grep -A 10 "\[env.development.vars\]" web/wrangler.toml | grep "JWT_SECRET" | wc -l)

if [ "$has_prod_jwt_in_toml" -eq 0 ]; then
    echo "⚠️  生产环境在 wrangler.toml 中没有配置 JWT_SECRET"
    echo "   这是正常的，应该使用 Cloudflare Secrets"
    echo "   请运行: ./fix-alipay-login.sh"
else
    echo "⚠️  生产环境在 wrangler.toml 中配置了 JWT_SECRET"
    echo "   建议改用 Cloudflare Secrets（更安全）"
fi

echo ""

if [ "$has_dev_jwt_in_toml" -gt 0 ]; then
    echo "✅ 开发环境已配置 JWT_SECRET"
else
    echo "❌ 开发环境未配置 JWT_SECRET"
fi

echo ""
echo "💡 建议："
echo "  1. 生产环境应使用 Cloudflare Secrets 存储 JWT_SECRET"
echo "  2. 运行 ./fix-alipay-login.sh 进行修复"
echo "  3. 查看 FIX_ALIPAY_LOGIN_401.md 了解详情"
