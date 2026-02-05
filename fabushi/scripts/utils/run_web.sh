#!/bin/bash

# 全球法布施Web应用启动脚本
echo "正在启动全球法布施Web应用..."

# 确保Flutter环境已就绪
echo "检查Flutter环境..."
flutter --version

# 清理旧的构建文件
echo "清理旧的构建文件..."
flutter clean

# 获取依赖
echo "获取依赖..."
flutter pub get

# 启动Web服务器
echo "启动Web服务器..."
flutter run -d chrome

echo "如果浏览器没有自动打开，请手动访问: http://localhost:8080"