#!/bin/bash

# Cloudflare Pages 专用构建脚本
set -e

echo "===== 开始构建用于 Cloudflare Pages 的 Flutter Web 应用 ====="

# 构建 Flutter Web 应用
echo "构建 Flutter Web 应用..."
flutter build web --release --web-renderer canvaskit --base-href /

# 复制 Cloudflare Pages 配置文件
echo "复制 Cloudflare Pages 配置文件..."
cp ../../_headers build/web/
cp ../../_redirects build/web/

# 复制必要的 Web 文件
echo "复制必要的 Web 文件..."
if [ -d "web/wasm-proxy/pkg" ]; then
    cp -r web/wasm-proxy/pkg build/web/wasm-proxy/
fi

if [ -f "web/service-worker.js" ]; then
    cp web/service-worker.js build/web/
fi

echo "===== 构建完成 ====="
echo "构建输出目录: build/web"
echo "可以直接上传到 Cloudflare Pages"