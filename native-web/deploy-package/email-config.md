# 邮箱服务配置指南

## 🚀 推荐配置：Resend（首选）✅ 已配置完成

### 1. 注册 Resend 账户 ✅
- 访问 [resend.com](https://resend.com)
- 使用 GitHub 或 Google 账户快速注册
- 免费计划：每月 10,000 封邮件

### 2. 获取 API Key ✅
1. 登录后进入 Dashboard
2. 点击 "API Keys" → "Create API Key"
3. 复制生成的 API Key（以 `re_` 开头）
4. **已配置**: `re_GVsTtV67_C7s7Gfi8K4iLE9tvqYo1DXUA`

### 3. 验证域名 ✅
1. 在 Dashboard 中点击 "Domains" → "Add Domain"
2. 输入你的域名（如：`ombhrum.com`）
3. 按照提示添加 DNS 记录：
   ```
   Type: TXT
   Name: @
   Value: resend-verification=xxxxxxxxxxxxxxxx
   ```
4. 等待验证完成（通常几分钟内）
5. **已验证**: `ombhrum.com` 域名验证完成

### 4. 环境变量配置 ✅
在 Cloudflare Workers 中已设置：
```
RESEND_API_KEY=re_GVsTtV67_C7s7Gfi8K4iLE9tvqYo1DXUA
FROM_EMAIL=amitabha@ombhrum.com
```

## 🔄 备用配置

### Cloudflare SendEmail
- 需要绑定 EMAIL 绑定
- 限制较多，仅支持已验证的收件人地址
- 适合测试环境

### MailChannels
- 需要 MAILCHANNELS_API_KEY
- 支持更多功能，但配置复杂
- 适合生产环境备用

## 📧 邮件模板优化

当前代码已支持：
- ✅ 纯文本邮件
- ✅ HTML 格式邮件（自动转换）
- ✅ 中文字体支持
- ✅ 响应式设计

## 🛠️ 故障排除

### 常见问题
1. **API Key 无效**：检查 RESEND_API_KEY 是否正确设置
2. **域名未验证**：确保在 Resend 中完成域名验证
3. **发件人地址错误**：FROM_EMAIL 必须是已验证域名下的地址

### 测试邮件发送
```bash
curl -X POST https://your-worker.your-subdomain.workers.dev/api/auth/send-verification-code \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","type":"register"}'
```

## 📊 性能对比

| 服务 | 免费额度 | 送达率 | 配置难度 | 推荐指数 |
|------|----------|--------|----------|----------|
| **Resend** | 10,000/月 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| MailChannels | 1,000/月 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| Cloudflare | 1,000/月 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

## 🎯 最佳实践

1. **优先使用 Resend**：配置简单，功能强大
2. **设置回退机制**：确保邮件服务的高可用性
3. **监控发送状态**：定期检查邮件发送日志
4. **域名验证**：使用自己的域名提高可信度
5. **测试环境**：先在测试环境验证配置

## 🎉 配置完成状态

### ✅ 已完成的配置
- **Resend 邮箱服务**: 完全配置并工作正常
- **域名验证**: `ombhrum.com` 已验证
- **API Key**: 已设置并测试通过
- **邮件发送**: 功能正常，支持验证码发送
- **回退机制**: Cloudflare SendEmail 作为备用服务

### 🚀 当前服务状态
- **主要服务**: Resend (每月10,000封免费邮件)
- **备用服务**: Cloudflare SendEmail
- **Worker URL**: https://fabushi.bhrumom.workers.dev
- **邮件功能**: 注册验证码、密码重置、用户通知

### 📧 测试结果
```bash
# 测试验证码发送 - 成功 ✅
curl -X POST https://fabushi.bhrumom.workers.dev/api/auth/send-verification-code \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","type":"register"}'

# 响应: {"message":"验证码已发送"}
```

### 🔧 维护建议
1. **定期检查**: 每月检查 Resend 使用量
2. **监控日志**: 使用 `wrangler tail` 监控邮件发送状态
3. **备份配置**: 保存好 API Key 和域名验证信息
4. **性能优化**: 根据需要调整邮件模板和发送策略
