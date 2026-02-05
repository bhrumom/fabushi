#!/bin/bash
# 生成软著程序鉴别材料
# 前30页 + 后30页，每页50行

cd "$(dirname "$0")"

SOURCE_FILE="源程序代码.txt"
FRONT_FILE="源程序_前30页.txt"
BACK_FILE="源程序_后30页.txt"

# 每页50行，30页 = 1500行
LINES_PER_PAGE=50
PAGES=30
TOTAL_LINES=$((LINES_PER_PAGE * PAGES))

# 获取源文件总行数
FILE_LINES=$(wc -l < "$SOURCE_FILE" | tr -d ' ')
echo "源代码总行数: $FILE_LINES"

# 提取前1500行
echo "生成前30页 (前${TOTAL_LINES}行)..."
head -n $TOTAL_LINES "$SOURCE_FILE" > "$FRONT_FILE"
echo "已生成: $FRONT_FILE"

# 提取后1500行
echo "生成后30页 (后${TOTAL_LINES}行)..."
tail -n $TOTAL_LINES "$SOURCE_FILE" > "$BACK_FILE"
echo "已生成: $BACK_FILE"

# 统计生成的文件行数
FRONT_LINES=$(wc -l < "$FRONT_FILE" | tr -d ' ')
BACK_LINES=$(wc -l < "$BACK_FILE" | tr -d ' ')

echo ""
echo "=========================================="
echo "生成完成！"
echo "=========================================="
echo "前30页文件: $FRONT_FILE ($FRONT_LINES 行)"
echo "后30页文件: $BACK_FILE ($BACK_LINES 行)"
echo ""
echo "下一步操作："
echo "1. 使用文本编辑器打开这两个文件"
echo "2. 设置字体为宋体/等宽字体，字号 10-12pt"
echo "3. 设置每页50行"
echo "4. 打印/导出为 PDF 格式"
echo ""
echo "或者使用 macOS 自带命令直接转 PDF："
echo "  cupsfilter -o page-top=36 -o page-bottom=36 \"$FRONT_FILE\" > 源程序_前30页.pdf"
echo "  cupsfilter -o page-top=36 -o page-bottom=36 \"$BACK_FILE\" > 源程序_后30页.pdf"
