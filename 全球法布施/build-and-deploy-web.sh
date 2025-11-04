#!/bin/bash

echo "开始构建并部署Flutter Web到Cloudflare..."

# 清理旧构建
echo "清理旧构建..."
flutter clean

# 构建Flutter Web
echo "构建Flutter Web..."
flutter build web --release

# 进入web目录
cd web

# 部署到Cloudflare
echo "部署到Cloudflare..."
npx wrangler deploy --env production

echo "部署完成！访问 https://flutter.ombhrum.com"
