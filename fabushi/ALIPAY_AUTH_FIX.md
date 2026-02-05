# 支付宝用户认证问题修复

## 问题描述

支付宝登录的用户在访问需要认证的 API 时返回 401 错误，而邮箱密码登录的用户可以正常访问。

## 根本原因

**数据存储不一致**：
- 支付宝用户数据保存在 **KV 存储** 中
- 邮箱用户数据保存在 **D1 数据库** 中
- 后端认证逻辑从 **D1 数据库** 查询用户
- 导致支付宝用户无法通过认证

## 解决方案

### 1. 统一数据存储

将支付宝用户数据迁移到 D1 数据库：

```sql
-- 创建支付宝绑定表
CREATE TABLE IF NOT EXISTS alipay_bindings (
  alipay_user_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  bound_at TEXT NOT NULL,
  FOREIGN KEY (username) REFERENCES users(username)
);
```

### 2. 更新代码

#### A. 数据库服务 (database.js)

添加通过支付宝 ID 查询用户的方法：

```javascript
async getUserByAlipayId(alipayUserId) {
  const binding = await this.db.prepare(
    'SELECT username FROM alipay_bindings WHERE alipay_user_id = ?'
  ).bind(alipayUserId).first();
  if (!binding) return null;
  return await this.getUser(binding.username);
}
```

#### B. 支付宝登录函数 (alipay-login-functions.js)

需要将所有 KV 操作替换为 D1 操作：

**查询用户：**
```javascript
// 旧代码 (KV)
const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);

// 新代码 (D1)
const existingBinding = await env.DB.prepare(
  'SELECT username FROM alipay_bindings WHERE alipay_user_id = ?'
).bind(alipayUserId).first();
```

**保存用户：**
```javascript
// 旧代码 (KV)
await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);

// 新代码 (D1)
await env.DB.prepare(`
  INSERT INTO users (username, email, password_hash, ...) 
  VALUES (?, ?, ?, ...)
`).bind(...).run();

await env.DB.prepare(
  'INSERT INTO alipay_bindings (alipay_user_id, username, bound_at) VALUES (?, ?, ?)'
).bind(alipayUserId, username, new Date().toISOString()).run();
```

### 3. 部署步骤

```bash
# 1. 创建数据库表
cd web
wrangler d1 execute DB --file=fix_alipay_d1.sql

# 2. 部署更新后的 Worker
wrangler deploy

# 或使用一键脚本
./deploy_alipay_d1_fix.sh
```

### 4. 数据迁移

现有的支付宝用户需要重新登录以迁移到 D1 数据库。

可选：编写迁移脚本将 KV 中的支付宝用户数据迁移到 D1。

## 需要修改的文件

1. ✅ `web/src/services/database.js` - 已添加 `getUserByAlipayId` 方法
2. ✅ `web/fix_alipay_d1.sql` - 已创建 SQL 脚本
3. ⚠️  `web/alipay-login-functions.js` - 需要手动替换所有 KV 操作
4. ✅ `deploy_alipay_d1_fix.sh` - 已创建部署脚本

## 测试验证

1. 使用支付宝登录
2. 尝试访问需要认证的 API（如购买会员）
3. 确认不再返回 401 错误

## 注意事项

- 支付宝用户的 `alipay_user_id` 字段需要添加到 `users` 表中
- 确保 `alipay_bindings` 表的外键约束正确
- 旧的 KV 数据可以保留作为备份，但不再使用

## 相关文件

- `web/src/services/database.js`
- `web/alipay-login-functions.js`
- `web/src/handlers/admin.js`
- `web/fix_alipay_d1.sql`
- `deploy_alipay_d1_fix.sh`
