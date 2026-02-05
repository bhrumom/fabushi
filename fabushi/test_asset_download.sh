#!/bin/bash

echo "🧪 测试首页经文下载和显示功能"
echo "================================"

echo "1. 清理缓存和重新构建..."
flutter clean
flutter pub get

echo "2. 运行应用进行测试..."
echo "请按照以下步骤测试："
echo "   a) 打开应用首页"
echo "   b) 点击'内置素材'按钮"
echo "   c) 选择一个经文进行下载"
echo "   d) 观察下载完成后是否出现在'已选文件'框中"
echo "   e) 再次选择相同经文，观察是否显示为已下载状态"

flutter run --debug

echo "测试完成！"