#!/bin/bash
# 生成软著源程序代码文件
# 用于计算机软件著作权登记

OUTPUT_FILE="源程序代码.txt"
cd "$(dirname "$0")/.."

echo "全球法布施 V1.0 源程序代码" > "软著材料/$OUTPUT_FILE"
echo "========================================" >> "软著材料/$OUTPUT_FILE"
echo "" >> "软著材料/$OUTPUT_FILE"

# 收集所有 Dart 源代码文件
find lib -name "*.dart" -type f | sort | while read file; do
    echo "" >> "软著材料/$OUTPUT_FILE"
    echo "// ========================================" >> "软著材料/$OUTPUT_FILE"
    echo "// 文件: $file" >> "软著材料/$OUTPUT_FILE"
    echo "// ========================================" >> "软著材料/$OUTPUT_FILE"
    echo "" >> "软著材料/$OUTPUT_FILE"
    cat "$file" >> "软著材料/$OUTPUT_FILE"
    echo "" >> "软著材料/$OUTPUT_FILE"
done

# 统计行数
total_lines=$(wc -l < "软著材料/$OUTPUT_FILE")
echo "源代码总行数: $total_lines"
echo "文件已生成: 软著材料/$OUTPUT_FILE"
