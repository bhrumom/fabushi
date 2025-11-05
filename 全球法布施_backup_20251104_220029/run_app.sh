#!/bin/bash

echo "正在启动全球法布施应用..."
echo "注意：file_picker插件的警告是正常的，不会影响应用功能"

# 清理并重新构建
flutter clean
flutter pub get

# 运行应用，忽略插件警告
flutter run -d macos 2>&1 | grep -v "file_picker.*references.*as the default plugin"