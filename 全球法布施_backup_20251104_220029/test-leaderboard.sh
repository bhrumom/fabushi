#!/bin/bash

echo "🧪 测试排行榜功能"
echo "=================="
echo ""

# 1. 测试排行榜 API
echo "1️⃣ 测试排行榜 API..."
RESPONSE=$(curl -s https://flutter.ombhrum.com/api/leaderboard)
echo "响应: $RESPONSE"
echo ""

# 2. 查询数据库中的用户数据
echo "2️⃣ 查询数据库中的用户传输数据..."
cd web
npx wrangler d1 execute fabushi-db --remote --command "SELECT username, total_transferred_bytes, last_transfer_at FROM users WHERE total_transferred_bytes > 0 ORDER BY total_transferred_bytes DESC LIMIT 5;" 2>/dev/null
echo ""

# 3. 查询所有用户数量
echo "3️⃣ 查询用户总数..."
npx wrangler d1 execute fabushi-db --remote --command "SELECT COUNT(*) as total_users FROM users;" 2>/dev/null
echo ""

echo "✅ 测试完成！"
echo ""
echo "📝 说明："
echo "  - 如果排行榜为空，说明还没有用户进行过传输"
echo "  - 用户需要使用应用发送文件后，数据才会显示在排行榜"
echo "  - 传输数据通过 /api/leaderboard/update 接口更新"
