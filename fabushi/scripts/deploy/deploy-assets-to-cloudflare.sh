#!/bin/bash

echo "开始部署assets到Cloudflare..."

# 进入web目录
cd "$(dirname "$0")/web"

# 复制assets到web目录
echo "复制assets文件..."
rm -rf assets
cp -r ../assets ./assets

# 部署到Cloudflare
echo "部署到Cloudflare..."
npx wrangler deploy --env production

echo "部署完成！"
