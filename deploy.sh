#!/bin/bash

# Cloudflare Pages 部署脚本
echo "准备部署到 Cloudflare Pages..."

# 进入 Flutter 项目目录
cd 全球法布施

# 1. 使用专用构建脚本
./cloudflare_build.sh

# 2. 使用 Wrangler CLI 部署（需要先安装 wrangler）
echo "使用以下命令部署:"
echo "cd 全球法布施"
echo "npm install -g wrangler"
echo "wrangler pages publish build/web --project-name=global-dharma-sharing"

echo "或者手动上传 全球法布施/build/web 目录到 Cloudflare Pages Dashboard"