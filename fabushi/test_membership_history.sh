#!/bin/bash

# 会员历史记录测试脚本
# 用途：测试购买记录和兑换记录API是否正常工作

set -e

echo "=========================================="
echo "会员历史记录 - API测试"
echo "=========================================="
echo ""

# 配置
API_BASE_URL="https://flutter.ombhrum.com"
TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
    echo "❌ 错误：请提供认证token"
    echo ""
    echo "用法："
    echo "  ./test_membership_history.sh YOUR_AUTH_TOKEN"
    echo ""
    exit 1
fi

echo "🔍 测试配置："
echo "  API地址：$API_BASE_URL"
echo "  Token：${TOKEN:0:20}..."
echo ""

# 测试购买记录API
echo "📋 测试购买记录API..."
echo "  GET /api/admin/purchase-history"
echo ""

PURCHASE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "$API_BASE_URL/api/admin/purchase-history" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

HTTP_CODE=$(echo "$PURCHASE_RESPONSE" | tail -n1)
PURCHASE_BODY=$(echo "$PURCHASE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 购买记录API响应成功 (HTTP $HTTP_CODE)"
    echo ""
    echo "响应内容："
    echo "$PURCHASE_BODY" | python3 -m json.tool 2>/dev/null || echo "$PURCHASE_BODY"
    echo ""
else
    echo "❌ 购买记录API响应失败 (HTTP $HTTP_CODE)"
    echo "响应内容："
    echo "$PURCHASE_BODY"
    echo ""
fi

# 测试兑换记录API
echo "📋 测试兑换记录API..."
echo "  GET /api/admin/redeem-history"
echo ""

REDEEM_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "$API_BASE_URL/api/admin/redeem-history" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

HTTP_CODE=$(echo "$REDEEM_RESPONSE" | tail -n1)
REDEEM_BODY=$(echo "$REDEEM_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 兑换记录API响应成功 (HTTP $HTTP_CODE)"
    echo ""
    echo "响应内容："
    echo "$REDEEM_BODY" | python3 -m json.tool 2>/dev/null || echo "$REDEEM_BODY"
    echo ""
else
    echo "❌ 兑换记录API响应失败 (HTTP $HTTP_CODE)"
    echo "响应内容："
    echo "$REDEEM_BODY"
    echo ""
fi

# 测试会员状态API
echo "📋 测试会员状态API..."
echo "  GET /api/stripe/membership-status"
echo ""

STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X GET "$API_BASE_URL/api/stripe/membership-status" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

HTTP_CODE=$(echo "$STATUS_RESPONSE" | tail -n1)
STATUS_BODY=$(echo "$STATUS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ 会员状态API响应成功 (HTTP $HTTP_CODE)"
    echo ""
    echo "响应内容："
    echo "$STATUS_BODY" | python3 -m json.tool 2>/dev/null || echo "$STATUS_BODY"
    echo ""
else
    echo "❌ 会员状态API响应失败 (HTTP $HTTP_CODE)"
    echo "响应内容："
    echo "$STATUS_BODY"
    echo ""
fi

echo "=========================================="
echo "✅ 测试完成"
echo "=========================================="
echo ""
echo "📝 总结："
echo "  - 购买记录API：$([ "$HTTP_CODE" = "200" ] && echo "✅ 正常" || echo "❌ 异常")"
echo "  - 兑换记录API：$([ "$HTTP_CODE" = "200" ] && echo "✅ 正常" || echo "❌ 异常")"
echo "  - 会员状态API：$([ "$HTTP_CODE" = "200" ] && echo "✅ 正常" || echo "❌ 异常")"
echo ""
