#!/bin/bash

# Video Feed 同步脚本
# 用于从 GitHub 仓库同步最新的 video_feed 代码

set -e

REPO_URL="https://github.com/Deatsilence/flutter-video-feed.git"
TEMP_DIR="temp_video_feed"
TARGET_DIR="lib/features/video_feed"

echo "🔄 开始同步 Video Feed 模块..."

# 检查是否已存在临时目录
if [ -d "$TEMP_DIR" ]; then
    echo "📂 更新现有仓库..."
    cd "$TEMP_DIR"
    git pull origin main
    cd ..
else
    echo "📥 克隆仓库..."
    git clone "$REPO_URL" "$TEMP_DIR"
fi

# 创建目标目录
mkdir -p "$TARGET_DIR"

# 复制核心代码
echo "📋 复制 video_feed 核心代码..."
cp -r "$TEMP_DIR/lib/features/video_feed/"* "$TARGET_DIR/"

# 复制依赖注入相关代码
echo "📋 复制依赖注入代码..."
mkdir -p "lib/core/video_feed_di"
cp "$TEMP_DIR/lib/core/di/dependency_injector.dart" "lib/core/video_feed_di/"

# 修复导入路径
echo "🔧 修复导入路径..."
find lib/features/video_feed -type f -name "*.dart" -exec sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' {} +
sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' lib/core/video_feed_di/video_feed_injector.dart
sed -i '' 's/package:flutter_video_feed/package:global_dharma_sharing/g' lib/screens/video_feed_screen.dart 2>/dev/null || true

echo "✅ 同步完成！"
echo ""
echo "⚠️  请手动完成以下步骤："
echo "1. 运行 'flutter pub get' 安装依赖"
echo "2. 检查 pubspec.yaml 中的依赖是否已添加"
echo "3. 如需要，运行 'flutter pub run build_runner build' 生成代码"
