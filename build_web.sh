#!/bin/bash

# Flutter Web 构建脚本
echo "开始构建 Flutter Web 应用..."

# 清理之前的构建
flutter clean

# 获取依赖
flutter pub get

# 构建 Web 应用
flutter build web --release --web-renderer html

echo "构建完成！输出目录: build/web"