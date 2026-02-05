#!/bin/bash

echo "🔧 修复支付宝用户认证问题..."

# 1. 创建支付宝绑定表
echo "📊 创建支付宝绑定表..."
cd web
wrangler d1 execute DB --file=fix_alipay_d1.sql

# 2. 部署更新后的 Worker
echo "🚀 部署 Worker..."
wrangler deploy

echo "✅ 修复完成！"
echo ""
echo "📝 说明："
echo "1. 已创建 alipay_bindings 表用于存储支付宝用户绑定"
echo "2. 已更新 database.js 添加 getUserByAlipayId 方法"
echo "3. 需要手动更新 alipay-login-functions.js 使用 D1 而不是 KV"
echo ""
echo "⚠️  重要：现有的支付宝用户需要重新登录以迁移到 D1 数据库"
