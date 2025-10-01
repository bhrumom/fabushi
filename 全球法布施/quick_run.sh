#!/bin/bash

echo "快速启动全球法布施应用..."
echo "跳过CocoaPods重新安装，直接运行应用"

cd "$(dirname "$0")"

# 直接运行应用
flutter run -d macos --verbose