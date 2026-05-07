#!/bin/bash

# 构建并部署 Flutter Web 到新的前端 Worker。

set -e

echo "📦 构建 Flutter Web..."
flutter build web --release --dart-define=API_BASE_URL=https://api.ombhrum.com

echo "🧹 清理不应发布到前端静态站点的旧 Worker 备份..."
rm -rf build/web/.wrangler build/web/.dart_tool
rm -rf build/web/node_modules build/web/dist build/web/src build/web/tests
rm -rf build/web/migrations build/web/wasm-proxy
rm -f build/web/.dev.vars build/web/.DS_Store build/web/.last_build_id
rm -f build/web/worker*.js build/web/migrate*.js
rm -f build/web/*.sql build/web/*.md build/web/package*.json build/web/wrangler*.toml

echo "🌐 部署前端 Worker..."
cd web
npx wrangler deploy --config wrangler-web.toml --env production

echo ""
echo "✅ 前端部署完成: https://flutter.ombhrum.com"
