#!/bin/bash

echo "🔧 部署支付宝macOS登录修复"
echo "=============================="

cd web

echo "1. 部署后端到Cloudflare Workers..."
wrangler deploy

if [ $? -eq 0 ]; then
    echo "✅ 后端部署成功"
else
    echo "❌ 后端部署失败"
    exit 1
fi

echo ""
echo "✅ 支付宝macOS登录修复部署完成！"
echo ""
echo "📝 修复内容："
echo "  - 添加 /api/auth/alipay/macos-callback 路由"
echo "  - 支持自定义scheme回调 (globaldharma://)"
echo "  - 恢复前端macOS平台代码"
echo ""
echo "🧪 测试步骤："
echo "  1. 运行应用: flutter run -d macos"
echo "  2. 点击'支付宝登录'或'支付宝一键注册'"
echo "  3. 完成支付宝授权"
echo "  4. 验证是否自动跳回应用并登录成功"
