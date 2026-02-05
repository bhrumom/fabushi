#!/bin/bash

# 支付宝登录 401 问题快速修复脚本

echo "🔧 支付宝登录 401 认证失败问题修复"
echo "======================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "web/wrangler.toml" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

echo "📋 问题分析："
echo "  - 邮箱登录正常 ✅"
echo "  - 支付宝登录返回 401 ❌"
echo "  - 原因：JWT_SECRET 未在生产环境配置"
echo ""

echo "🔍 检查当前配置..."
cd web

# 检查是否已登录 Cloudflare
if ! wrangler whoami &> /dev/null; then
    echo "❌ 未登录 Cloudflare，请先运行: wrangler login"
    exit 1
fi

echo "✅ 已登录 Cloudflare"
echo ""

# 列出当前的 secrets
echo "📝 当前生产环境的 Secrets："
wrangler secret list --env production 2>/dev/null || echo "  (无法获取列表或没有 secrets)"
echo ""

# 提示用户设置 JWT_SECRET
echo "🔐 需要设置 JWT_SECRET"
echo ""
echo "请选择操作："
echo "  1) 设置新的 JWT_SECRET（推荐）"
echo "  2) 查看详细修复文档"
echo "  3) 退出"
echo ""
read -p "请输入选项 (1-3): " choice

case $choice in
    1)
        echo ""
        echo "⚠️  重要提示："
        echo "  - JWT_SECRET 应该是一个强随机字符串（至少32位）"
        echo "  - 建议使用密码生成器生成"
        echo "  - 设置后所有旧的 token 将失效，用户需要重新登录"
        echo ""
        read -p "是否继续？(y/n): " confirm
        
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            echo ""
            echo "正在设置 JWT_SECRET..."
            echo "（系统会提示输入 secret 值）"
            echo ""
            
            # 设置生产环境 secret
            wrangler secret put JWT_SECRET --env production
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "✅ JWT_SECRET 设置成功！"
                echo ""
                echo "📦 正在重新部署..."
                wrangler deploy --env production
                
                if [ $? -eq 0 ]; then
                    echo ""
                    echo "🎉 修复完成！"
                    echo ""
                    echo "📝 后续步骤："
                    echo "  1. 清除应用缓存和登录状态"
                    echo "  2. 重新使用支付宝登录测试"
                    echo "  3. 验证是否能正常获取用户信息"
                else
                    echo ""
                    echo "❌ 部署失败，请检查错误信息"
                fi
            else
                echo ""
                echo "❌ 设置 JWT_SECRET 失败"
            fi
        else
            echo "已取消"
        fi
        ;;
    2)
        echo ""
        echo "📖 查看详细文档："
        echo "  文件位置: FIX_ALIPAY_LOGIN_401.md"
        echo ""
        if [ -f "../FIX_ALIPAY_LOGIN_401.md" ]; then
            echo "按 Enter 键查看文档，按 Ctrl+C 退出"
            read
            less ../FIX_ALIPAY_LOGIN_401.md
        else
            echo "❌ 文档文件不存在"
        fi
        ;;
    3)
        echo "已退出"
        exit 0
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

cd ..
