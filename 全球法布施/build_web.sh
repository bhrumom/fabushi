#!/bin/bash

# 全球法布施 Web构建脚本
# 此脚本编译WebAssembly模块并构建Flutter Web应用

set -e

echo "===== 开始构建全球法布施Web应用 ====="

# 检查必要工具
echo "检查必要工具..."

# 检查Rust和wasm-pack
if ! command -v rustc &> /dev/null || ! command -v wasm-pack &> /dev/null; then
    echo "错误: 需要安装Rust和wasm-pack"
    echo "请访问 https://www.rust-lang.org/tools/install 安装Rust"
    echo "然后运行: cargo install wasm-pack"
    exit 1
fi

# 检查Flutter
if ! command -v flutter &> /dev/null; then
    echo "错误: 需要安装Flutter"
    echo "请访问 https://flutter.dev/docs/get-started/install"
    exit 1
fi

# 编译WebAssembly模块
echo "编译WebAssembly模块..."
cd web/wasm-proxy
wasm-pack build --target web --out-dir pkg
cd ../..

# 确保pkg目录存在于web目录中
mkdir -p web/wasm-proxy/pkg

# 构建Flutter Web应用
echo "构建Flutter Web应用..."
flutter build web --release

# 复制WebAssembly文件到构建目录
echo "复制WebAssembly文件到构建目录..."
cp -r web/wasm-proxy/pkg build/web/wasm-proxy/

# 复制Service Worker到构建目录
echo "复制Service Worker到构建目录..."
cp web/service-worker.js build/web/

echo "===== 构建完成 ====="
echo "您可以在build/web目录中找到构建好的应用"
echo "要测试应用，请运行:"
echo "cd build/web && python -m http.server 8000"
echo "然后在浏览器中访问: http://localhost:8000"