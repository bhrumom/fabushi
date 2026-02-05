#!/bin/bash

echo "🔥 Firebase 自动配置脚本（FlutterFire CLI）"
echo "=============================================="
echo ""

# 检查 Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI 未安装"
    echo "📦 正在安装 Firebase CLI..."
    npm install -g firebase-tools
else
    echo "✅ Firebase CLI 已安装"
fi

# 检查 FlutterFire CLI
if ! command -v flutterfire &> /dev/null; then
    echo "❌ FlutterFire CLI 未安装"
    echo "📦 正在安装 FlutterFire CLI..."
    dart pub global activate flutterfire_cli
    
    # 添加到 PATH
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    echo ""
    echo "⚠️  请将以下行添加到 ~/.zshrc 或 ~/.bash_profile："
    echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"'
    echo ""
else
    echo "✅ FlutterFire CLI 已安装"
fi

echo ""
echo "🔐 正在登录 Firebase..."
firebase login

echo ""
echo "🔧 正在配置 Firebase 项目..."
echo "   Bundle ID: com.ombhrum.fabushi"
echo ""

flutterfire configure \
  --ios-bundle-id=com.ombhrum.fabushi \
  --macos-bundle-id=com.ombhrum.fabushi \
  --android-package-name=com.ombhrum.fabushi

echo ""
echo "🧹 清理项目..."
flutter clean
flutter pub get

echo ""
echo "✅ Firebase 配置完成！"
echo ""
echo "📝 下一步："
echo "1. 在 Firebase Console 启用 Authentication"
echo "2. 启用 Email/Password 和 Google 登录"
echo "3. 运行: flutter run -d macos"
echo ""
echo "🌐 打开 Firebase Console:"
echo "   firebase open"
