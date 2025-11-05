#!/bin/bash

PROJECT_ID="fabushi-71777"
BUNDLE_ID="com.ombhrum.fabushi"

echo "🔥 Firebase 应用手动添加指南"
echo "============================="
echo ""
echo "请按照以下命令逐个执行："
echo ""

echo "1️⃣ 添加 iOS 应用:"
echo "firebase apps:create IOS --project=$PROJECT_ID"
echo "   然后输入: $BUNDLE_ID"
echo ""

echo "2️⃣ 添加 Android 应用:"
echo "firebase apps:create ANDROID --project=$PROJECT_ID"
echo "   然后输入: $BUNDLE_ID"
echo ""

echo "3️⃣ 添加 Web 应用:"
echo "firebase apps:create WEB --project=$PROJECT_ID"
echo "   然后输入: 全球法布施"
echo ""

echo "4️⃣ 重新配置 FlutterFire:"
echo "flutterfire configure --project=$PROJECT_ID"
echo ""

echo "或者直接运行 FlutterFire 配置（推荐）:"
echo "flutterfire configure --project=$PROJECT_ID"
