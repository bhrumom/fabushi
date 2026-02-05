#!/bin/bash

# 修复 video_feed 导入路径脚本

echo "🔧 修复 video_feed 模块导入路径..."

# 替换所有 flutter_video_feed 为 global_dharma_sharing
find lib/features/video_feed -type f -name "*.dart" -exec sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' {} +
sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' lib/core/video_feed_di/video_feed_injector.dart
sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' lib/screens/video_feed_screen.dart

echo "✅ 导入路径修复完成！"
echo ""
echo "运行以下命令完成修复："
echo "flutter clean"
echo "flutter pub get"
echo "flutter pub run build_runner build --delete-conflicting-outputs"
