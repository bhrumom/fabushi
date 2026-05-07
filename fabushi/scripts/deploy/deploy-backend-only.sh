#!/bin/bash

# 仅部署 Cloudflare 后端（不构建、不上传 Flutter Web）

echo "🚀 部署后端 API 到旧 Cloudflare Worker 项目..."

cd web
npx wrangler deploy --env production

echo ""
echo "✅ 部署完成！"
echo ""
echo "🧪 测试排行榜API..."
curl -s https://api.ombhrum.com/api/leaderboard

echo ""
echo ""
echo "✨ 修复内容："
echo "  1. 旧 Worker 项目作为纯 API 后端部署"
echo "  2. 部署过程不依赖 build/web"
echo "  3. 前端可独立部署，并通过 API_BASE_URL 指向后端"
