#!/bin/bash

# 创建部署包目录
DEPLOY_DIR="deploy-package"
mkdir -p "$DEPLOY_DIR"

echo "正在下载核心代码文件到 $DEPLOY_DIR 目录..."

# 核心配置文件
cp wrangler.toml "$DEPLOY_DIR/"
cp _headers "$DEPLOY_DIR/"

# 主要 JavaScript 文件
cp worker.js "$DEPLOY_DIR/"
cp service-worker.js "$DEPLOY_DIR/"
cp sender.js "$DEPLOY_DIR/"
cp stripe-config.js "$DEPLOY_DIR/"
cp dharma-assets.js "$DEPLOY_DIR/"
cp r2-assets.js "$DEPLOY_DIR/"

# HTML 页面文件
cp index.html "$DEPLOY_DIR/"
cp login.html "$DEPLOY_DIR/"
cp register.html "$DEPLOY_DIR/"
cp membership.html "$DEPLOY_DIR/"
cp forgot-password.html "$DEPLOY_DIR/"
cp reset-password.html "$DEPLOY_DIR/"

# 工具和管理文件
cp cache-manager.html "$DEPLOY_DIR/"
cp r2-debug-center.html "$DEPLOY_DIR/"

# 其他重要的 JS 工具文件
cp download-manager.js "$DEPLOY_DIR/"
cp performance-monitor.js "$DEPLOY_DIR/"
cp large-file-downloader.js "$DEPLOY_DIR/"
cp global-beacon-targets.js "$DEPLOY_DIR/"
cp global-country-servers.js "$DEPLOY_DIR/"

# 图标文件
cp favicon.ico "$DEPLOY_DIR/"

echo "核心代码文件已下载到 $DEPLOY_DIR 目录"
echo "文件列表："
ls -la "$DEPLOY_DIR/"