#!/bin/bash

# 仅部署后端修复（不重新构建 Flutter Web）

echo "🚀 部署后端修复到 Cloudflare Workers..."

cd web
npx wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo ""
echo "🧪 测试排行榜API..."
curl -s https://flutter.ombhrum.com/api/leaderboard

echo ""
echo ""
echo "✨ 修复内容："
echo "  1. 数据库查询添加了 COALESCE 处理 NULL 值"
echo "  2. 添加了完善的错误处理"
echo "  3. 即使查询失败也返回空数组而不是500错误"
echo "  4. 前端服务改为返回空数组而不是抛出异常"
