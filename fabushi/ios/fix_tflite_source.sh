#!/bin/bash

# 定义 podspec 路径
PODSPEC_PATH="$HOME/.cocoapods/repos/trunk/Specs/d/9/6/TensorFlowLiteSwift/0.0.1-nightly.20250619/TensorFlowLiteSwift.podspec.json"

if [ ! -f "$PODSPEC_PATH" ]; then
    echo "❌ 找不到 TensorFlowLiteSwift podspec 文件: $PODSPEC_PATH"
    echo "这可能是因为 CocoaPods repo 没有更新。请先运行 pod repo update。"
    exit 1
fi

echo "备份原始 podspec..."
cp "$PODSPEC_PATH" "${PODSPEC_PATH}.bak"

echo "替换 Git Clone 为 HTTP ZIP 下载..."
# 使用 sed 替换。注意 macOS 的 sed 语法
sed -i '' 's/"git": "https:\/\/github.com\/tensorflow\/tensorflow.git",/"http": "https:\/\/github.com\/tensorflow\/tensorflow\/archive\/d969db94661693f84d7be32a5525045873f429df.zip"/g' "$PODSPEC_PATH"
sed -i '' '/"commit": "d969db94661693f84d7be32a5525045873f429df"/d' "$PODSPEC_PATH"

echo "✅ 替换成功！"
echo ""
echo "现在请返回 ios 目录执行："
echo "cd ~/Documents/fabushi/fabushi/ios"
echo "pod install # 注意不要加 --repo-update，否则可能覆盖我们的修改"
echo "如果执行成功，ZIP 包的大小约 ~200MB（相比 2GB+ 的 Git 仓库小了很多）"
