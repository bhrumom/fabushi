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
RED='\033[0;31m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# 0. 检查字体子集是否存在
echo -e "${BLUE}📋 检查字体子集...${NC}"
if [ ! -f "fonts/subset/NotoSansSC-Regular-subset.woff2" ]; then
    echo -e "${YELLOW}⚠️ 字体子集不存在，正在生成...${NC}"
    python3 scripts/generate_font_subset.py
fi

SUBSET_SIZE=$(du -sh fonts/subset 2>/dev/null | cut -f1 || echo "N/A")
echo -e "字体子集大小: ${GREEN}${SUBSET_SIZE}${NC}"
echo ""

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
  --dart-define=FLUTTER_WEB_AUTO_DETECT=true

echo ""
echo -e "${GREEN}✅ 构建完成!${NC}"
echo ""

# 4. 复制优化版 Service Worker
if [ -f "web/optimized_service_worker.js" ]; then
    cp web/optimized_service_worker.js build/web/service-worker.js
    echo -e "${GREEN}✅ 优化版 Service Worker 已复制${NC}"
fi

# 5. 清理构建产物中的原始OTF字体（只保留子集化的WOFF2）
if [ -d "build/web/assets/fonts" ]; then
    rm -f build/web/assets/fonts/*.otf 2>/dev/null
    rm -f build/web/assets/fonts/*.ttf 2>/dev/null
    echo -e "${GREEN}✅ 已清理原始字体文件，只保留子集化WOFF2${NC}"
fi

# 6. 分析构建产物
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

# 字体资源
FONTS_SIZE=$(du -sh build/web/assets/fonts 2>/dev/null | cut -f1 || echo "N/A")
echo -e "字体资源: ${GREEN}${FONTS_SIZE}${NC}"

# 统计所有 JS 文件
JS_COUNT=$(find build/web -name "*.js" | wc -l | tr -d ' ')
echo -e "JavaScript 文件数: ${YELLOW}${JS_COUNT}${NC}"

echo "-----------------------------------"
echo ""

# 6. 优化验证清单
echo -e "${BLUE}✅ 优化清单验证:${NC}"
echo ""

# 检查字体大小
FONTS_BYTES=$(du -s build/web/assets/fonts 2>/dev/null | cut -f1 || echo "0")
if [ "$FONTS_BYTES" -lt 10000 ]; then
    echo -e "${GREEN}[✓] 字体已子集化 (${FONTS_SIZE})${NC}"
else
    echo -e "${YELLOW}[!] 字体可能未子集化 (${FONTS_SIZE})${NC}"
fi

# 检查main.dart.js大小
MAIN_BYTES=$(stat -f%z build/web/main.dart.js 2>/dev/null || echo "0")
if [ "$MAIN_BYTES" -lt 5000000 ]; then
    echo -e "${GREEN}[✓] 初始 JS 包 < 5MB (${MAIN_JS_SIZE})${NC}"
else
    echo -e "${YELLOW}[!] 初始 JS 包 > 5MB (${MAIN_JS_SIZE})${NC}"
fi

# 检查Service Worker
if [ -f "build/web/service-worker.js" ]; then
    echo -e "${GREEN}[✓] 优化版 Service Worker 已就位${NC}"
else
    echo -e "${YELLOW}[!] Service Worker 未找到${NC}"
fi

echo ""
echo -e "${BLUE}💡 性能测试建议:${NC}"
echo ""
echo "1. 本地测试 (推荐):"
echo "   cd build/web"
echo "   python3 -m http.server 8080"
echo "   open http://localhost:8080"
echo ""
echo "2. 检查初始加载资源:"
echo "   - 打开 Chrome DevTools → Network"
echo "   - 勾选 'Disable cache'"
echo "   - 刷新页面并检查瀑布流"
echo ""

echo -e "${GREEN}🎉 构建完成! 准备测试性能...${NC}"

