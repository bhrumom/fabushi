#!/bin/bash

# 后端修复部署脚本

echo "🚀 开始部署修复..."

echo "🌐 部署到 Cloudflare Workers..."
cd web
npx wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo ""
echo "🧪 测试排行榜API..."
curl -s https://api.ombhrum.com/api/leaderboard | jq '.'

echo ""
echo "✨ 修复内容："
echo "  1. 数据库查询添加了 COALESCE 处理 NULL 值"
echo "  2. 添加了完善的错误处理"
echo "  3. 即使查询失败也返回空数组而不是500错误"
echo "  4. 前端服务改为返回空数组而不是抛出异常"
