# 🚀 KV到D1数据库迁移

## 快速开始

### 一键迁移（推荐）

```bash
cd web
./migrate-to-d1.sh production
```

## 📚 完整文档

所有迁移相关文档位于 `web/` 目录：

### 🎯 必读文档
1. **[迁移方案总结](KV_TO_D1_MIGRATION_SUMMARY.md)** - 开始这里 ⭐
2. **[文档索引](web/D1_MIGRATION_INDEX.md)** - 查找所有文档
3. **[快速参考](web/QUICK_REFERENCE.md)** - 常用命令

### 📖 详细指南
- **[部署指南](web/D1_DEPLOYMENT_GUIDE.md)** - 完整部署流程
- **[代码迁移指南](web/D1_MIGRATION_GUIDE.md)** - KV vs D1代码对照
- **[迁移检查清单](web/MIGRATION_CHECKLIST.md)** - 逐步验证

### 🛠️ 实施文件
- **[schema.sql](web/schema.sql)** - 数据库表结构
- **[migrate-kv-to-d1.js](web/migrate-kv-to-d1.js)** - 数据迁移脚本
- **[worker-d1.js](web/worker-d1.js)** - D1版本Worker
- **[migrate-to-d1.sh](web/migrate-to-d1.sh)** - 自动化脚本

## 🎯 迁移内容

### ✅ 迁移到D1
- 用户数据
- 订单数据
- 兑换码数据
- 购买记录
- 兑换记录

### ✅ 保留在KV
- 验证码（临时）
- 频率限制（临时）
- 密码重置令牌（临时）
- 缓存数据（临时）

## 📊 预期收益

- ⚡ 查询性能提升 30-75%
- 💰 成本降低约 50%
- 🔍 支持复杂SQL查询
- 🔄 支持事务操作
- 📈 更好的数据管理

## 🔧 系统要求

- Wrangler CLI (最新版本)
- Cloudflare账户
- 现有KV数据访问权限

## 📞 获取帮助

- 📖 查看 [文档索引](web/D1_MIGRATION_INDEX.md)
- 📧 邮箱: support@fabushi.com
- 📝 查看日志: `wrangler tail`

## ⚠️ 重要提示

1. **迁移前务必备份数据**
2. **先在开发环境测试**
3. **准备好回滚方案**
4. **监控迁移后性能**

---

**详细文档请查看 [KV_TO_D1_MIGRATION_SUMMARY.md](KV_TO_D1_MIGRATION_SUMMARY.md)**

**愿此功德回向法界众生，同证菩提！** 🙏
