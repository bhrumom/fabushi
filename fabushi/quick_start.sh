#!/bin/bash

# 全球法布施 - 快速启动脚本
# 使用重构后的代码架构

set -e

echo "🙏 全球法布施 - 快速启动"
echo "=========================="
echo ""

# 检查Flutter环境
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到Flutter命令"
    echo "请先安装Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter环境检查通过"
echo ""

# 清理构建缓存
echo "🧹 清理构建缓存..."
flutter clean > /dev/null 2>&1

# 获取依赖
echo "📦 获取依赖包..."
flutter pub get

# 代码格式化
echo "✨ 格式化代码..."
dart format lib/ --line-length 100 > /dev/null 2>&1

echo ""
echo "✅ 准备完成！"
echo ""
echo "可用命令："
echo "  flutter run              # 运行应用（默认设备）"
echo "  flutter run -d chrome    # 运行Web版本"
echo "  flutter run -d android   # 运行Android版本"
echo "  flutter run -d ios       # 运行iOS版本"
echo ""
echo "构建命令："
echo "  flutter build apk --release        # Android APK"
echo "  flutter build ios --release        # iOS"
echo "  flutter build web --release        # Web"
echo "  flutter build macos --release      # macOS"
echo "  flutter build windows --release    # Windows"
echo ""
echo "📚 查看文档："
echo "  README.md                  # 项目说明"
echo "  CLEANUP_COMPLETE.md        # 清理报告"
echo "  MIGRATION_GUIDE.md         # 迁移指南"
echo "  MAINTENANCE_GUIDE.md       # 维护指南"
echo ""
echo "🚀 现在可以运行应用了！"
echo ""
echo "愿此功德回向法界众生，同证菩提！🙏"
