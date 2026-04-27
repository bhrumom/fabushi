#!/bin/bash

# 管理员会员激活脚本
# 用途：为管理员账号生成兑换码并自动兑换

set -e

echo "=========================================="
echo "管理员会员激活脚本"
echo "=========================================="
echo ""

# 配置
API_BASE_URL="https://flutter.ombhrum.com"
TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
    echo "❌ 错误：请提供管理员认证token"
    echo ""
    echo "用法："
    echo "  ./activate_admin_membership.sh YOUR_ADMIN_TOKEN"
    echo ""
    echo "获取token的方法："
    echo "  1. 登录管理员账号"
    echo "  2. 打开浏览器开发者工具 (F12)"
    echo "  3. 查看 Network 标签"
    echo "  4. 找到任意API请求的 Authorization header"
    echo "  5. 复制 'Bearer ' 后面的token"
    echo ""
    exit 1
fi

echo "🔍 配置信息："
echo "  API地址：$API_BASE_URL"
echo "  Token：${TOKEN:0:20}..."
echo ""

# 步骤1：生成年度会员兑换码
echo "📝 步骤1：生成年度会员兑换码..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_BASE_URL/api/admin/create-redeem-code" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "yearly",
        "quantity": 1,
        "description": "管理员账号会员激活"
    }')

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
CREATE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ 生成兑换码失败 (HTTP $HTTP_CODE)"
    echo "响应内容："
    echo "$CREATE_BODY"
    exit 1
fi

echo "✅ 兑换码生成成功"
echo ""

# 提取兑换码
REDEEM_CODE=$(echo "$CREATE_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['codes'][0])" 2>/dev/null)

if [ -z "$REDEEM_CODE" ]; then
    echo "❌ 无法提取兑换码"
    echo "响应内容："
    echo "$CREATE_BODY" | python3 -m json.tool 2>/dev/null || echo "$CREATE_BODY"
    exit 1
fi

echo "🎫 兑换码：$REDEEM_CODE"
echo ""

# 步骤2：使用兑换码激活会员
echo "📝 步骤2：使用兑换码激活会员..."
USE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$API_BASE_URL/api/admin/use-redeem-code" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"code\": \"$REDEEM_CODE\"}")

HTTP_CODE=$(echo "$USE_RESPONSE" | tail -n1)
USE_BODY=$(echo "$USE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ 兑换失败 (HTTP $HTTP_CODE)"
    echo "响应内容："
    echo "$USE_BODY"
    exit 1
fi

echo "✅ 兑换成功！"
echo ""
echo "响应内容："
echo "$USE_BODY" | python3 -m json.tool 2>/dev/null || echo "$USE_BODY"
echo ""

# 步骤3：验证会员状态
echo "📝 步骤3：验证会员状态..."
STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "$API_BASE_URL/api/stripe/membership-status" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

HTTP_CODE=$(echo "$STATUS_RESPONSE" | tail -n1)
STATUS_BODY=$(echo "$STATUS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 会员状态查询成功"
    echo ""
    echo "当前会员状态："
    echo "$STATUS_BODY" | python3 -m json.tool 2>/dev/null || echo "$STATUS_BODY"
else
    echo "⚠️  会员状态查询失败 (HTTP $HTTP_CODE)"
    echo "$STATUS_BODY"
fi

echo ""
echo "=========================================="
echo "✅ 管理员会员激活完成！"
echo "=========================================="
echo ""
echo "📋 下一步："
echo "1. 刷新应用页面"
echo "2. 进入会员中心"
echo "3. 确认会员状态已更新"
echo ""
