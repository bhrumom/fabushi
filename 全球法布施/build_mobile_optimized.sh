#!/bin/bash

# 移动端优化构建脚本
echo "构建移动端优化版本..."

# 构建时启用代码分割和压缩
flutter build web \
  --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --source-maps \
  --pwa-strategy=offline-first

# 复制配置文件
cp ../_headers ../_redirects build/web/

echo "移动端优化构建完成！"