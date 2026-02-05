#!/bin/bash

# WebSocket 功能测试脚本
# 用于快速测试 WebSocket 连接是否正常

set -e

echo "🧪 WebSocket 功能测试"
echo ""

# 检查是否在项目根目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

# 测试后端 WebSocket 端点
echo "1️⃣ 测试后端 WebSocket 端点..."
echo ""

BACKEND_URL="https://flutter.ombhrum.com"
WS_URL="wss://flutter.ombhrum.com/api/online/ws?activityType=zen_room"

echo "📡 测试 HTTP 端点: $BACKEND_URL/health"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/health" || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP 端点正常 (状态码: $HTTP_STATUS)"
else
    echo "⚠️ HTTP 端点异常 (状态码: $HTTP_STATUS)"
fi

echo ""
echo "🔌 WebSocket 端点: $WS_URL"
echo "   (需要在应用中测试 WebSocket 连接)"
echo ""

# 测试 HTTP 降级端点
echo "2️⃣ 测试 HTTP 降级端点..."
echo ""

# 测试获取在线人数
echo "📊 测试获取在线人数..."
COUNT_RESPONSE=$(curl -s "$BACKEND_URL/api/online/count?activityType=zen_room")
echo "响应: $COUNT_RESPONSE"

if echo "$COUNT_RESPONSE" | grep -q "count"; then
    echo "✅ HTTP 降级端点正常"
else
    echo "⚠️ HTTP 降级端点可能异常"
fi

echo ""
echo "3️⃣ 启动 Flutter 应用进行完整测试..."
echo ""
echo "请按照以下步骤测试："
echo "1. 运行应用: flutter run"
echo "2. 进入禅修室或全球发送页面"
echo "3. 查看控制台日志"
echo ""
echo "预期日志："
echo "  ✅ 成功: 🔌 尝试连接 WebSocket: wss://..."
echo "  ✅ 成功: ✅ WebSocket 连接成功"
echo "  ⚠️ 降级: 📡 WebSocket 不可用，使用 HTTP 轮询"
echo ""
echo "4. 观察在线人数是否正常显示和更新"
echo ""

read -p "是否现在启动 Flutter 应用？(y/n): " start_app

if [ "$start_app" = "y" ] || [ "$start_app" = "Y" ]; then
    echo ""
    echo "🚀 启动 Flutter 应用..."
    flutter run
else
    echo ""
    echo "📖 测试完成！查看 WEBSOCKET_ENABLED.md 了解更多信息"
fi
