#!/bin/bash

echo "🧪 测试游客模式修复"
echo "===================="

# 清理缓存
echo "1. 清理Flutter缓存..."
flutter clean

# 获取依赖
echo "2. 获取依赖..."
flutter pub get

# 检查关键文件
echo "3. 检查关键文件..."
if [ -f "assets/earth_texture.jpg" ]; then
    echo "✅ 地球纹理文件存在"
else
    echo "❌ 地球纹理文件缺失"
fi

if [ -f "lib/widgets/earth_globe_widget.dart" ]; then
    echo "✅ 地球组件文件存在"
else
    echo "❌ 地球组件文件缺失"
fi

if [ -f "lib/screens/my_profile_screen.dart" ]; then
    echo "✅ 个人中心文件存在"
else
    echo "❌ 个人中心文件缺失"
fi

# 检查修复内容
echo "4. 检查修复内容..."
if grep -q "errorBuilder" lib/widgets/earth_globe_widget.dart; then
    echo "✅ 地球组件错误处理已添加"
else
    echo "❌ 地球组件错误处理缺失"
fi

if grep -q "游客模式" lib/screens/my_profile_screen.dart; then
    echo "✅ 游客模式UI已添加"
else
    echo "❌ 游客模式UI缺失"
fi

echo ""
echo "🚀 测试步骤："
echo "1. 运行应用: flutter run"
echo "2. 点击登录页面的'以游客身份继续'"
echo "3. 检查是否正常显示主界面（不再黑屏）"
echo "4. 切换到'我的'标签页，检查游客模式UI"
echo ""
echo "✅ 修复完成！现在可以测试游客模式了。"