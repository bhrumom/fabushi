#!/bin/bash

# 优化资源文件脚本
echo "优化大文件以符合 Cloudflare Pages 25MB 限制..."

# 压缩 IP 数据文件
if [ -f "assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv" ]; then
    echo "压缩 IP 数据文件..."
    gzip -c assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv > assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv.gz
    
    # 检查压缩后大小
    original_size=$(ls -lh assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv | awk '{print $5}')
    compressed_size=$(ls -lh assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv.gz | awk '{print $5}')
    
    echo "原始文件: $original_size"
    echo "压缩后: $compressed_size"
    
    # 如果压缩后小于 20MB，替换原文件
    if [ $(stat -f%z assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv.gz) -lt 20971520 ]; then
        mv assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv.gz assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv
        echo "✅ 文件已压缩并替换"
    else
        rm assets/ip_data/GeoLite2-Country-Blocks-IPv4.csv.gz
        echo "⚠️ 压缩后仍然过大，考虑删除此文件"
    fi
fi

echo "优化完成！"