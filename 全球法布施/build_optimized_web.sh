#!/bin/bash

# Flutter Web 优化构建脚本
# 实现 Google Earth 级别的加载性能

set -e

echo "🚀 Flutter Web 优化构建开始..."
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 清理旧构建
echo -e "${BLUE}📦 清理旧构建...${NC}"
flutter clean
rm -rf build/web

# 2. 获取依赖
echo -e "${BLUE}📥 获取依赖...${NC}"
flutter pub get

# 3. 优化构建
echo -e "${BLUE}⚙️  执行优化构建...${NC}"
echo ""

flutter build web \
  --release \
  --tree-shake-icons \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=true \
  --source-maps

echo ""
echo -e "${GREEN}✅ 构建完成!${NC}"
echo ""

# 4. 分析构建产物
echo -e "${BLUE}📊 构建产物分析:${NC}"
echo "-----------------------------------"

# 总体大小
TOTAL_SIZE=$(du -sh build/web | cut -f1)
echo -e "总大小: ${YELLOW}${TOTAL_SIZE}${NC}"

# 关键文件
if [ -f "build/web/main.dart.js" ]; then
    MAIN_JS_SIZE=$(ls -lh build/web/main.dart.js | awk '{print $5}')
    echo -e "main.dart.js: ${YELLOW}${MAIN_JS_SIZE}${NC}"
fi

if [ -f "build/web/canvaskit/canvaskit.wasm" ]; then
    CANVAS_SIZE=$(ls -lh build/web/canvaskit/canvaskit.wasm | awk '{print $5}')
    echo -e "canvaskit.wasm: ${YELLOW}${CANVAS_SIZE}${NC}"
fi

# 统计所有 JS 文件
JS_COUNT=$(find build/web -name "*.js" | wc -l | tr -d ' ')
echo -e "JavaScript 文件数: ${YELLOW}${JS_COUNT}${NC}"

echo "-----------------------------------"
echo ""

# 5. 性能提示
echo -e "${BLUE}💡 性能测试建议:${NC}"
echo ""
echo "1. 本地测试 (推荐):"
echo "   cd build/web"
echo "   python3 -m http.server 8080"
echo "   open http://localhost:8080"
echo ""
echo "2. Lighthouse 性能测试:"
echo "   npm install -g @lhci/cli"
echo "   lhci autorun --config=.lighthouserc.json"
echo ""
echo "3. 检查初始加载资源:"
echo "   - 打开 Chrome DevTools → Network"
echo "   - 勾选 'Disable cache'"
echo "   - 刷新页面并检查瀑布流"
echo ""

# 6. 优化验证清单
echo -e "${BLUE}✅ 优化清单验证:${NC}"
echo ""
echo "[ ] 初始 JS 包 < 5MB"
echo "[ ] Three.js 延迟加载 (首屏不加载)"
echo "[ ] 佛像模型从 CDN 加载 (不在bundle)"
echo "[ ] 骨架屏立即显示 (< 100ms)"
echo "[ ] HTML 渲染器快速启动"
echo "[ ] Lighthouse 性能分数 > 90"
echo ""

echo -e "${GREEN}🎉 构建完成! 准备测试性能...${NC}"
